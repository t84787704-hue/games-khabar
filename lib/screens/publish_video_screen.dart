import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/gamer_theme.dart';
import '../services/gamer_auth_service.dart';
import '../services/background_upload_manager.dart';
import '../services/video_upload_service.dart';
import '../widgets/gamer_avatar.dart';

/// Option B Flow: Compress First (720p HD, 1500k bitrate, <90MB), Upload After
class PublishVideoScreen extends StatefulWidget {
  final File? initialVideoFile;
  const PublishVideoScreen({super.key, this.initialVideoFile});

  @override
  State<PublishVideoScreen> createState() => _PublishVideoScreenState();
}

class _PublishVideoScreenState extends State<PublishVideoScreen> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _originalVideoFile;
  File? _compressedVideoFile;
  double _originalSizeMB = 0.0;
  double _compressedSizeMB = 0.0;
  String? _videoFileName;

  bool _isCompressing = false;
  double _compressionProgress = 0.0;
  String _compressionStatus = '';

  String _selectedGameTag = 'BGMI';
  bool _isPublishing = false;

  final List<String> _gameTags = [
    'BGMI',
    'Free Fire',
    'COD Mobile',
    'Valorant',
    'GTA V',
    'PUBG',
    'Apex Mobile',
    'Minecraft',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialVideoFile != null) {
      _loadVideoFile(widget.initialVideoFile!);
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  /// Option B: User selects video (even 500-600MB) -> Immediately start compression
  Future<void> _loadVideoFile(File file) async {
    try {
      final bytes = await file.length();
      final double mb = bytes / (1024 * 1024);
      final fileName = file.path.split(Platform.pathSeparator).last;

      setState(() {
        _originalVideoFile = file;
        _compressedVideoFile = null;
        _originalSizeMB = mb;
        _compressedSizeMB = mb;
        _videoFileName = fileName;
        _isCompressing = mb > 20.0;
        _compressionProgress = 0.05;
        _compressionStatus = mb > 20.0
            ? "⚡ Optimizing... 5% - Compressing from ${mb.toInt()}MB to ~80MB"
            : "Ready for Upload (${mb.toInt()}MB • Original)";
      });

      // If file is already <= 20MB, ready right away
      if (mb <= 20.0) {
        setState(() {
          _compressedVideoFile = file;
          _isCompressing = false;
          _compressionProgress = 1.0;
          _compressionStatus = "Ready for Upload (Compressed: ${mb.toInt()}MB • 720p HD)";
        });
        return;
      }

      // Immediately start 720p compression with 1500k bitrate
      final compressed = await VideoUploadService.compressVideoOptionB(
        inputFile: file,
        estimatedDurationSeconds: 180,
        onProgress: (p) {
          if (!mounted) return;
          final pct = (p * 100).toInt();
          setState(() {
            _compressionProgress = p;
            _compressionStatus = "⚡ Optimizing... $pct% - Compressing from ${_originalSizeMB.toInt()}MB to ~80MB";
          });
        },
        onStatus: (status) {
          if (!mounted) return;
          setState(() {
            _compressionStatus = status;
          });
        },
      );

      final compBytes = await compressed.length();
      final compMB = compBytes / (1024 * 1024);

      if (!mounted) return;
      setState(() {
        _compressedVideoFile = compressed;
        _compressedSizeMB = compMB;
        _isCompressing = false;
        _compressionProgress = 1.0;
        _compressionStatus = "Ready for Upload (Compressed: ${compMB.toInt()}MB • 720p HD)";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCompressing = false;
        _compressionStatus = "Notice: $e";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst("Exception: ", "")),
          backgroundColor: GamerTheme.redAccent,
        ),
      );
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final picked = await _picker.pickVideo(source: source);
      if (picked != null) {
        final file = File(picked.path);
        await _loadVideoFile(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick video: $e'),
            backgroundColor: GamerTheme.redAccent,
          ),
        );
      }
    }
  }

  void _showPickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: GamerTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: GamerTheme.borderDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Select Gaming Video',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Maximum duration: 3 minutes (180 seconds) • Auto-Compress to 720p HD',
                style: TextStyle(color: GamerTheme.neonGreen, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: GamerTheme.accentBlue.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.video_library_rounded, color: GamerTheme.accentBlue),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Any size up to 1000MB (Auto-compressed)', style: TextStyle(color: GamerTheme.textMuted, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickVideo(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: GamerTheme.accentOrange.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.videocam_rounded, color: GamerTheme.accentOrange),
                ),
                title: const Text('Record with Camera', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Max 3 min clip recording', style: TextStyle(color: GamerTheme.textMuted, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickVideo(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePublish() async {
    final fileToUpload = _compressedVideoFile ?? _originalVideoFile;
    if (fileToUpload == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a video clip to publish (Max 3 min)'),
          backgroundColor: GamerTheme.redAccent,
        ),
      );
      return;
    }

    if (_isCompressing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚡ Video is still optimizing... Please wait a moment!'),
          backgroundColor: GamerTheme.accentBlue,
        ),
      );
      return;
    }

    final user = GamerAuthService().currentGamer;
    final uid = GamerAuthService().currentUser?.uid;
    if (user == null || uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to publish videos'), backgroundColor: GamerTheme.redAccent),
      );
      return;
    }

    setState(() => _isPublishing = true);

    final caption = _captionController.text.trim();
    BackgroundUploadManager().startVideoUpload(
      videoFile: fileToUpload,
      text: caption.isNotEmpty ? caption : '🔥 Gaming highlight by @${user.username}',
      gameTag: _selectedGameTag,
      userId: uid,
      username: user.username,
      displayName: user.displayName,
      userPhoto: user.photoUrl,
      estimatedDurationSeconds: 180,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text('Uploading 720p HD clip to Cloudinary in background... 🚀'),
            ),
          ],
        ),
        backgroundColor: GamerTheme.cardDark,
        duration: Duration(seconds: 3),
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final user = GamerAuthService().currentGamer;

    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      appBar: AppBar(
        backgroundColor: GamerTheme.surfaceDark,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.video_call_rounded, color: GamerTheme.accentOrange, size: 24),
            SizedBox(width: 8),
            Text('Publish Video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            child: ElevatedButton.icon(
              onPressed: (_isPublishing || _isCompressing || _originalVideoFile == null) ? null : _handlePublish,
              style: ElevatedButton.styleFrom(
                backgroundColor: GamerTheme.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              icon: _isCompressing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(
                _isCompressing ? 'Optimizing...' : 'Publish',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header
            Row(
              children: [
                GamerAvatar(
                  photoUrl: user?.photoUrl ?? '',
                  displayName: user?.displayName ?? 'Gamer',
                  radius: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            user?.displayName ?? 'Gamer',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          if (user?.isVerified == true) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, color: GamerTheme.neonGreen, size: 16),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: GamerTheme.cardElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: GamerTheme.borderDark),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.public_rounded, size: 12, color: GamerTheme.textMuted),
                            SizedBox(width: 4),
                            Text('Public • Gaming Community', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: GamerTheme.neonGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: GamerTheme.neonGreen.withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, color: GamerTheme.neonGreen, size: 14),
                      SizedBox(width: 4),
                      Text('MAX 3 MIN', style: TextStyle(color: GamerTheme.neonGreen, fontSize: 11, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Caption Field
            TextField(
              controller: _captionController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
              decoration: InputDecoration(
                hintText: "What is this video clip about? (e.g., Epic 1v4 AWM clutch in Miramar!)...",
                hintStyle: const TextStyle(color: GamerTheme.textMuted, fontSize: 14),
                border: InputBorder.none,
                filled: true,
                fillColor: GamerTheme.cardDark,
                contentPadding: const EdgeInsets.all(14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: GamerTheme.borderDark),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: GamerTheme.accentBlue, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Video Picker / Video Info Card with Option B Compression UI
            _originalVideoFile == null
                ? InkWell(
                    onTap: _showPickerBottomSheet,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      decoration: BoxDecoration(
                        color: GamerTheme.cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: GamerTheme.accentBlue.withOpacity(0.6), width: 1.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: GamerTheme.blueOrangeGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.video_library_rounded, color: Colors.white, size: 36),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Select Video to Publish',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Supports clips up to 3 min (even 500-600MB) • Auto-Compress to ~80MB',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: GamerTheme.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                : Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: GamerTheme.cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isCompressing ? GamerTheme.accentBlue : GamerTheme.neonGreen,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header with File Info
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: GamerTheme.cardElevated,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: GamerTheme.accentBlue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.movie_filter_rounded, color: GamerTheme.accentBlue, size: 28),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _videoFileName ?? 'video_clip.mp4',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Original: ${_originalSizeMB.toStringAsFixed(1)} MB • 720p HD Max 3m',
                                      style: const TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.change_circle_rounded, color: GamerTheme.accentBlue, size: 26),
                                onPressed: _isCompressing ? null : _showPickerBottomSheet,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: GamerTheme.redAccent, size: 24),
                                onPressed: _isCompressing
                                    ? null
                                    : () {
                                        setState(() {
                                          _originalVideoFile = null;
                                          _compressedVideoFile = null;
                                          _originalSizeMB = 0.0;
                                          _compressedSizeMB = 0.0;
                                          _videoFileName = null;
                                          _isCompressing = false;
                                        });
                                      },
                              ),
                            ],
                          ),
                        ),

                        // Option B Compression Status & Progress UI
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _isCompressing
                                        ? Icons.bolt_rounded
                                        : Icons.check_circle_rounded,
                                    color: _isCompressing ? GamerTheme.accentOrange : GamerTheme.neonGreen,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _compressionStatus.isNotEmpty
                                          ? _compressionStatus
                                          : 'Preparing video optimization...',
                                      style: TextStyle(
                                        color: _isCompressing ? Colors.white : GamerTheme.neonGreen,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              if (_isCompressing) ...[
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: _compressionProgress > 0 ? _compressionProgress : null,
                                    minHeight: 6,
                                    backgroundColor: GamerTheme.cardElevated,
                                    valueColor: const AlwaysStoppedAnimation<Color>(GamerTheme.accentBlue),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Target: under 90MB (720p HD)',
                                      style: TextStyle(color: GamerTheme.textMuted.withOpacity(0.8), fontSize: 11),
                                    ),
                                    Text(
                                      '${(_compressionProgress * 100).toInt()}%',
                                      style: const TextStyle(
                                        color: GamerTheme.accentOrange,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

            const SizedBox(height: 20),

            // Game Tag Selector
            const Text('Select Game Tag', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _gameTags.map((tag) {
                final isSelected = _selectedGameTag == tag;
                return ChoiceChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedGameTag = tag);
                  },
                  backgroundColor: GamerTheme.cardDark,
                  selectedColor: GamerTheme.accentBlue,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : GamerTheme.textGray,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? GamerTheme.accentBlue : GamerTheme.borderDark,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // Bottom Publish Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: Container(
                decoration: BoxDecoration(
                  gradient: (_isPublishing || _isCompressing || _originalVideoFile == null)
                      ? null
                      : GamerTheme.blueOrangeGradient,
                  color: (_isPublishing || _isCompressing || _originalVideoFile == null)
                      ? GamerTheme.cardElevated
                      : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ElevatedButton.icon(
                  onPressed: (_isPublishing || _isCompressing || _originalVideoFile == null) ? null : _handlePublish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isCompressing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                        )
                      : const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                  label: Text(
                    _isCompressing
                        ? 'Optimizing Video (${(_compressionProgress * 100).toInt()}%)...'
                        : 'Publish Video (Max 3 Min)',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
