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
import '../services/cloudinary_service.dart';

/// Full-featured, completely rebuilt Clip & Meme upload modal.
/// - Clear, isolated buttons (no accidental gallery triggers)
/// - Pick from Phone Gallery, Instant 1-tap Sample Clips, Paste URL, or Camera
/// - Video Preview with Play/Pause and Dual-handle Trimmer
/// - Independent "SHARE CLIP TO FEED" button that uploads to Cloudinary & Firestore
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
  // Selected video state
  File? _selectedFile;
  String? _networkVideoUrl;
  String? _videoName;
  int? _videoSizeBytes;
  Duration _videoDuration = Duration.zero;

  VideoPlayerController? _videoController;
  bool _isVideoInitializing = false;
  bool _isPickerActive = false;

  // Trimmer state
  RangeValues _trimRange = const RangeValues(0, 30);

  // Form state
  final TextEditingController _captionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _selectedGameTag = 'PUBG Mobile';
  bool _highlightMediaPrompt = false;

  // Upload state
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';
  bool _isCancelled = false;

  // Popular Game Tags
  final List<String> _gameTags = const [
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

  // Guaranteed instant sample gaming clips
  final List<Map<String, String>> _sampleClips = const [
    {
      'title': '1v4 PUBG Clutch Moment! 🔥',
      'tag': 'PUBG Mobile',
      'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    },
    {
      'title': 'BGMI Pochinki Bridge Spray Wipeout 💀',
      'tag': 'BGMI',
      'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
    },
    {
      'title': 'Free Fire AWM Headshot Highlights 🎯',
      'tag': 'Free Fire',
      'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
    },
    {
      'title': 'COD Mobile Sniper Quickscope Ace ⚡',
      'tag': 'COD Mobile',
      'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyBlazes.mp4',
    },
  ];

  @override
  void initState() {
    super.initState();
    _captionController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    _scrollController.dispose();
    _videoController?.pause();
    _videoController?.dispose();
    super.dispose();
  }

  bool get _hasVideo => _selectedFile != null || (_networkVideoUrl != null && _networkVideoUrl!.isNotEmpty);

  String _formatSeconds(double sec) {
    final s = sec.round();
    final minutes = s ~/ 60;
    final remaining = s % 60;
    return '${minutes.toString().padLeft(1, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // ==========================================
  // 1. VIDEO SELECTION METHODS
  // ==========================================

  /// Pick video from phone gallery
  Future<void> _pickVideoFromGallery() async {
    if (_isPickerActive || _isUploading) return;
    setState(() {
      _isPickerActive = true;
      _highlightMediaPrompt = false;
    });

    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickVideo(source: ImageSource.gallery);

      if (picked == null) {
        // User cancelled gallery selection
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

      const maxBytes = 150 * 1024 * 1024; // 150MB
      if (size > maxBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Video is too large (max 150MB allowed)'),
              backgroundColor: GamerTheme.redAccent,
            ),
          );
        }
        return;
      }

      final name = picked.name.isNotEmpty ? picked.name : file.path.split('/').last;

      if (mounted) {
        setState(() {
          _selectedFile = file;
          _networkVideoUrl = null;
          _videoName = name.isNotEmpty ? name : 'clip.mp4';
          _videoSizeBytes = size > 0 ? size : null;
          if (_captionController.text.trim().isEmpty) {
            _captionController.text = 'Insane Gaming Clip! 🔥🎮';
          }
        });
      }

      await _setupVideoPlayer(file: file);
    } catch (e) {
      debugPrint('Gallery pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open video from gallery: $e. You can also pick a Quick Test Clip!'),
            backgroundColor: GamerTheme.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickerActive = false;
        });
      }
    }
  }

  /// Pick video from Camera
  Future<void> _recordVideoFromCamera() async {
    if (_isPickerActive || _isUploading) return;
    setState(() {
      _isPickerActive = true;
      _highlightMediaPrompt = false;
    });

    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickVideo(source: ImageSource.camera);

      if (picked == null) return;

      final file = File(picked.path);
      final size = await file.length();
      final name = picked.name.isNotEmpty ? picked.name : 'camera_clip.mp4';

      if (mounted) {
        setState(() {
          _selectedFile = file;
          _networkVideoUrl = null;
          _videoName = name;
          _videoSizeBytes = size;
          if (_captionController.text.trim().isEmpty) {
            _captionController.text = 'Recorded Gameplay Clip! 📹🎮';
          }
        });
      }

      await _setupVideoPlayer(file: file);
    } catch (e) {
      debugPrint('Camera error: $e');
    } finally {
      if (mounted) setState(() => _isPickerActive = false);
    }
  }

  /// Select one of the instant gaming sample clips (100% works without device files)
  Future<void> _selectSampleClip(Map<String, String> sample) async {
    if (_isUploading) return;

    setState(() {
      _highlightMediaPrompt = false;
      _selectedFile = null;
      _networkVideoUrl = sample['url']!;
      _videoName = sample['title']!;
      _videoSizeBytes = 3 * 1024 * 1024;
      _selectedGameTag = sample['tag']!;
      _captionController.text = sample['title']!;
    });

    await _setupVideoPlayer(networkUrl: sample['url']!);
  }

  /// Paste direct video URL dialog
  void _openPasteUrlDialog() {
    final urlCtrl = TextEditingController();
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
              'Enter direct MP4, Cloudinary or web video link:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://example.com/gameplay.mp4',
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
              final raw = urlCtrl.text.trim();
              if (raw.isEmpty || (!raw.startsWith('http://') && !raw.startsWith('https://'))) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid https:// URL'), backgroundColor: GamerTheme.redAccent),
                );
                return;
              }
              Navigator.pop(ctx);
              setState(() {
                _selectedFile = null;
                _networkVideoUrl = raw;
                _videoName = raw.split('/').last.split('?').first;
                if (_videoName!.isEmpty) _videoName = 'video_clip.mp4';
                _videoSizeBytes = 5 * 1024 * 1024;
                if (_captionController.text.trim().isEmpty) {
                  _captionController.text = 'Gaming Moment! 🔥🏆';
                }
              });
              _setupVideoPlayer(networkUrl: raw);
            },
            child: const Text('Attach Video', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Remove selected video
  void _clearSelectedVideo() {
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    setState(() {
      _selectedFile = null;
      _networkVideoUrl = null;
      _videoName = null;
      _videoSizeBytes = null;
      _videoDuration = Duration.zero;
      _trimRange = const RangeValues(0, 30);
      _isVideoInitializing = false;
    });
  }

  /// Initialize video preview player safely
  Future<void> _setupVideoPlayer({File? file, String? networkUrl}) async {
    setState(() {
      _isVideoInitializing = true;
    });

    try {
      await _videoController?.pause();
      await _videoController?.dispose();
      _videoController = null;

      final controller = file != null
          ? VideoPlayerController.file(file)
          : VideoPlayerController.networkUrl(Uri.parse(networkUrl!));

      await controller.initialize().timeout(const Duration(seconds: 8));

      final duration = controller.value.duration;
      final totalSec = duration.inSeconds.toDouble().clamp(1.0, 180.0);

      await controller.setLooping(false);
      await controller.setVolume(1.0);

      controller.addListener(() {
        if (!mounted || _videoController == null) return;
        final currentSec = _videoController!.value.position.inMilliseconds / 1000.0;
        if (currentSec >= _trimRange.end) {
          _videoController!.seekTo(Duration(milliseconds: (_trimRange.start * 1000).round()));
        }
      });

      if (mounted) {
        setState(() {
          _videoController = controller;
          _videoDuration = duration;
          _trimRange = RangeValues(0, totalSec);
          _isVideoInitializing = false;
        });
        controller.play();
      }
    } catch (e) {
      debugPrint('Video player setup note: $e');
      if (mounted) {
        setState(() {
          _isVideoInitializing = false;
          if (_videoDuration == Duration.zero) {
            _videoDuration = const Duration(seconds: 30);
            _trimRange = const RangeValues(0, 30);
          }
        });
      }
    }
  }

  // ==========================================
  // 2. SHARING & UPLOAD HANDLER
  // ==========================================

  Future<void> _handleShareClip() async {
    if (_isUploading) return;

    // 1. Check if media is attached
    if (!_hasVideo) {
      setState(() {
        _highlightMediaPrompt = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please select a video first (from Gallery, Sample Clips, or URL)!'),
          backgroundColor: GamerTheme.accentOrange,
          duration: Duration(seconds: 3),
        ),
      );
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }

    // 2. Caption check
    String caption = _captionController.text.trim();
    if (caption.isEmpty) {
      caption = 'Insane Gaming Clip! 🔥🎮';
    }

    // 3. Start upload state
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.05;
      _uploadStatus = 'Preparing gaming clip... 🚀';
      _isCancelled = false;
    });

    _videoController?.pause();

    try {
      String finalVideoUrl = '';
      String finalThumbnailUrl = '';
      String finalPublicId = '';
      double finalDuration = 30.0;
      double finalOrigDuration = 30.0;

      // Direct file upload to Cloudinary
      if (_selectedFile != null) {
        setState(() {
          _uploadStatus = 'Uploading to Cloudinary... 🚀';
        });

        final uploadResult = await _uploadFileToCloudinary(
          file: _selectedFile!,
          trimStart: _trimRange.start,
          trimEnd: _trimRange.end,
          onProgress: (prog) {
            if (mounted && !_isCancelled) {
              setState(() {
                _uploadProgress = prog;
                _uploadStatus = 'Uploading to Cloudinary (${(prog * 100).toInt()}%)... 🚀';
              });
            }
          },
        );

        finalVideoUrl = uploadResult['videoUrl'] as String;
        finalThumbnailUrl = uploadResult['thumbnailUrl'] as String;
        finalPublicId = uploadResult['publicId'] as String;
        finalDuration = uploadResult['duration'] as double;
        finalOrigDuration = uploadResult['originalDuration'] as double;
      } else if (_networkVideoUrl != null) {
        // Direct network link or sample clip
        finalVideoUrl = _networkVideoUrl!;
        finalThumbnailUrl = _networkVideoUrl!;
        finalPublicId = 'online_${DateTime.now().millisecondsSinceEpoch}';
        finalDuration = (_trimRange.end - _trimRange.start).clamp(1.0, 180.0);
        finalOrigDuration = finalDuration;

        setState(() {
          _uploadProgress = 0.8;
          _uploadStatus = 'Publishing clip to Feed... ⚡';
        });
      }

      setState(() {
        _uploadStatus = 'Saving to Clips Feed... ⚡';
      });

      // Save document to Firestore collection 'clips'
      final gamer = widget.currentGamer ?? GamerAuthService().currentGamer;
      final currentUid = gamer?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_gamer';
      final username = gamer?.username ?? 'gamer';
      final displayName = gamer?.displayName ?? 'Gamer';
      final userAvatar = gamer?.photoUrl ?? '';

      final docRef = FirebaseFirestore.instance.collection('clips').doc();
      final clipPayload = {
        'id': docRef.id,
        'videoUrl': finalVideoUrl,
        'mediaUrl': finalVideoUrl,
        'thumbnail': finalThumbnailUrl,
        'thumbnailUrl': finalThumbnailUrl,
        'publicId': finalPublicId,
        'caption': caption,
        'title': caption,
        'gameTag': _selectedGameTag,
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
      };

      await docRef.set(clipPayload);
      // Also update legacy collection for full compatibility
      FirebaseFirestore.instance.collection('gamer_clips').doc(docRef.id).set(clipPayload).catchError((_) {});

      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 1.0;
        });
        Navigator.pop(context);
        widget.onUploadSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔥 Gaming clip uploaded to Cloudinary and live in feed!'),
            backgroundColor: GamerTheme.accentOrange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Upload failure: $e');
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
          _uploadStatus = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e. You can try a Quick Test Clip or check internet!'),
            backgroundColor: GamerTheme.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Cloudinary multi-preset uploader with streaming progress
  Future<Map<String, dynamic>> _uploadFileToCloudinary({
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
        request.fields['tags'] = 'gaming,$_selectedGameTag';

        int bytesSent = 0;
        final fileStream = file.openRead();
        final progressStream = fileStream.transform(
          StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleData: (data, sink) {
              if (_isCancelled) {
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

          // Apply video trim transformations
          String finalVideoUrl = rawSecureUrl;
          final totalSec = duration > 0 ? duration : (_videoDuration.inSeconds > 0 ? _videoDuration.inSeconds.toDouble() : 0.0);
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
          debugPrint('Cloudinary preset $preset failed with ${response.statusCode}');
        }
      } catch (err) {
        debugPrint('Cloudinary attempt with preset $preset error: $err');
      }
    }

    throw Exception('Failed to upload to Cloudinary. Please check internet connection.');
  }

  // ==========================================
  // 3. UI BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
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
                        _isCancelled = true;
                        _isUploading = false;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // SECTION 1: MEDIA SELECTION / PREVIEW
            const Text(
              'STEP 1: SELECT VIDEO CLIP',
              style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),

            // IF NO VIDEO SELECTED: SHOW SOURCE OPTIONS
            if (!_hasVideo) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: GamerTheme.bgDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _highlightMediaPrompt ? GamerTheme.accentOrange : GamerTheme.borderDark,
                    width: _highlightMediaPrompt ? 2 : 1,
                  ),
                  boxShadow: _highlightMediaPrompt
                      ? [
                          BoxShadow(
                            color: GamerTheme.accentOrange.withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Primary Option: Phone Gallery Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GamerTheme.accentOrange,
                          foregroundColor: GamerTheme.bgDark,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        onPressed: (_isUploading || _isPickerActive) ? null : _pickVideoFromGallery,
                        icon: _isPickerActive
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: GamerTheme.bgDark, strokeWidth: 2),
                              )
                            : const Icon(Icons.photo_library_rounded, size: 20),
                        label: Text(
                          _isPickerActive ? 'OPENING GALLERY...' : 'CHOOSE FROM PHONE GALLERY',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Secondary Options Row: Camera & Paste Link
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: GamerTheme.borderLight),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: (_isUploading || _isPickerActive) ? null : _recordVideoFromCamera,
                            icon: const Icon(Icons.videocam_rounded, size: 16, color: GamerTheme.accentOrange),
                            label: const Text('Record Video', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                            onPressed: (_isUploading || _isPickerActive) ? null : _openPasteUrlDialog,
                            icon: const Icon(Icons.link_rounded, size: 16, color: Colors.white70),
                            label: const Text('Paste Link', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(color: GamerTheme.borderDark, height: 1),
                    const SizedBox(height: 12),

                    // Quick Sample Clips Header
                    const Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: GamerTheme.accentOrange, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'OR TAP A QUICK TEST CLIP (INSTANT):',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Quick Sample Clips Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _sampleClips.map((sample) {
                        return ActionChip(
                          backgroundColor: GamerTheme.cardDark,
                          side: const BorderSide(color: GamerTheme.accentOrange),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          avatar: const Icon(Icons.sports_esports_rounded, color: GamerTheme.accentOrange, size: 16),
                          label: Text(
                            sample['tag']!,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5),
                          ),
                          onPressed: _isUploading ? null : () => _selectSampleClip(sample),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // IF VIDEO IS SELECTED: SHOW PREVIEW & CONTROLS
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
                        height: 200,
                        width: double.infinity,
                        color: Colors.black,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_videoController != null && _videoController!.value.isInitialized)
                              AspectRatio(
                                aspectRatio: _videoController!.value.aspectRatio > 0
                                    ? _videoController!.value.aspectRatio
                                    : (16 / 9),
                                child: VideoPlayer(_videoController!),
                              )
                            else if (_isVideoInitializing)
                              const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(color: GamerTheme.accentOrange),
                                  SizedBox(height: 10),
                                  Text(
                                    'Loading video player...',
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
                                    _videoName ?? 'Video Clip Selected',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Ready to upload and share',
                                    style: TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),

                            // Play / Pause Overlay Button
                            if (_videoController != null && _videoController!.value.isInitialized)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (_videoController!.value.isPlaying) {
                                      _videoController!.pause();
                                    } else {
                                      _videoController!.play();
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.55),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white30),
                                  ),
                                  child: Icon(
                                    _videoController!.value.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),

                            // Top Left Size Badge
                            Positioned(
                              top: 8,
                              left: 8,
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
                                      _videoSizeBytes != null
                                          ? '${(_videoSizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB'
                                          : 'Video',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Top Right Remove / Change Button
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: _isUploading ? null : _clearSelectedVideo,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: GamerTheme.redAccent.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.close_rounded, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Change',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Video Trimmer Controls
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
                                'Length: ${_formatSeconds(selectedDurationSec)} / ${_formatDuration(_videoDuration)}',
                                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Range Slider
                          RangeSlider(
                            values: _trimRange,
                            min: 0.0,
                            max: (_videoDuration.inSeconds > 0
                                ? _videoDuration.inSeconds.toDouble()
                                : 30.0).clamp(1.0, 180.0),
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
                                    _videoController?.seekTo(
                                      Duration(milliseconds: (values.start * 1000).round()),
                                    );
                                  },
                          ),

                          // Quick trim duration presets
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text('Quick Trim: ', style: TextStyle(color: Colors.white54, fontSize: 10.5)),
                              _buildQuickTrimBtn('15s', 15),
                              const SizedBox(width: 6),
                              _buildQuickTrimBtn('30s', 30),
                              const SizedBox(width: 6),
                              _buildQuickTrimBtn('60s', 60),
                              const SizedBox(width: 6),
                              _buildQuickTrimBtn('Full', 180),
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

            // SECTION 2: CAPTION INPUT
            const Text(
              'STEP 2: CLIP CAPTION / TITLE',
              style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _captionController,
              maxLength: 120,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. Crazy 1v4 clutch in Pochinki! 🔥 #BGMI',
                hintStyle: const TextStyle(color: GamerTheme.textMuted),
                filled: true,
                fillColor: GamerTheme.bgDark,
                counterStyle: const TextStyle(color: GamerTheme.textMuted, fontSize: 10),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: GamerTheme.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: GamerTheme.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: GamerTheme.accentOrange, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // SECTION 3: GAME TAG SELECTION
            Row(
              children: [
                const Text(
                  'STEP 3: SELECT GAME TAG',
                  style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: GamerTheme.accentOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _selectedGameTag,
                    style: const TextStyle(color: GamerTheme.accentOrange, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _gameTags.map((tag) {
                final isSelected = _selectedGameTag == tag;
                return ChoiceChip(
                  label: Text(tag),
                  selected: isSelected,
                  selectedColor: GamerTheme.accentOrange,
                  backgroundColor: GamerTheme.bgDark,
                  labelStyle: TextStyle(
                    color: isSelected ? GamerTheme.bgDark : GamerTheme.textWhite,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
                    fontSize: 11,
                  ),
                  side: BorderSide(
                    color: isSelected ? GamerTheme.accentOrange : GamerTheme.borderDark,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedGameTag = tag;
                      });
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // UPLOAD PROGRESS BAR (When uploading)
            if (_isUploading) ...[
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
                              _uploadStatus.isNotEmpty ? _uploadStatus : 'Uploading clip...',
                              style: const TextStyle(color: GamerTheme.accentOrange, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isCancelled = true;
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
              const SizedBox(height: 16),
            ],

            // PROMINENT SHARE BUTTON
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
                onPressed: _isUploading ? null : _handleShareClip,
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
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _hasVideo ? Icons.rocket_launch_rounded : Icons.check_circle_outline_rounded,
                            color: GamerTheme.bgDark,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _hasVideo ? 'SHARE CLIP TO FEED 🚀' : 'SHARE CLIP TO FEED 🚀',
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

  Widget _buildQuickTrimBtn(String label, double sec) {
    return InkWell(
      onTap: _isUploading
          ? null
          : () {
              final total = _videoDuration.inSeconds > 0 ? _videoDuration.inSeconds.toDouble() : 30.0;
              setState(() {
                if (sec >= total) {
                  _trimRange = RangeValues(0, total);
                } else {
                  _trimRange = RangeValues(0, sec.clamp(1.0, total));
                }
              });
              _videoController?.seekTo(Duration(milliseconds: (_trimRange.start * 1000).round()));
              _videoController?.play();
            },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: GamerTheme.cardDark,
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
