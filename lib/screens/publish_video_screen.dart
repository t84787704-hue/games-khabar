import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/gamer_theme.dart';
import '../services/gamer_auth_service.dart';
import '../services/background_upload_manager.dart';
import '../widgets/gamer_avatar.dart';

/// Facebook-Style Dedicated Video Publish Screen
/// Enforces Maximum 3 Minutes Video limit with fast hardware compression and chunked upload.
class PublishVideoScreen extends StatefulWidget {
  final File? initialVideoFile;

  const PublishVideoScreen({
    super.key,
    this.initialVideoFile,
  });

  @override
  State<PublishVideoScreen> createState() => _PublishVideoScreenState();
}

class _PublishVideoScreenState extends State<PublishVideoScreen> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _videoFile;
  double _fileSizeMB = 0.0;
  String? _videoFileName;
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

  Future<void> _loadVideoFile(File file) async {
    try {
      final bytes = await file.length();
      setState(() {
        _videoFile = file;
        _fileSizeMB = bytes / (1024 * 1024);
        _videoFileName = file.path.split(Platform.pathSeparator).last;
      });
    } catch (e) {
      debugPrint("Error reading video file: $e");
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final picked = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 3), // Strict 3 minute limit
      );
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
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Maximum duration: 3 minutes (180 seconds)',
                style: TextStyle(
                  color: GamerTheme.neonGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
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
                subtitle: const Text('MP4, MOV up to 3 minutes', style: TextStyle(color: GamerTheme.textMuted, fontSize: 12)),
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
    if (_videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a video clip to publish (Max 3 min)'),
          backgroundColor: GamerTheme.redAccent,
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

    final caption = _captionController.text.trim();

    // Start TikTok/Facebook-style background upload
    BackgroundUploadManager().startVideoUpload(
      videoFile: _videoFile!,
      text: caption.isNotEmpty ? caption : '🔥 Gaming highlight by @${user.username}',
      gameTag: _selectedGameTag,
      userId: uid,
      username: user.username,
      displayName: user.displayName,
      userPhoto: user.photoUrl,
      estimatedDurationSeconds: 180, // Cap at 3 minutes
    );

    // Provide instant feedback and close screen immediately like Facebook/TikTok
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.flash_on_rounded, color: Colors.yellow, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text('Video publishing in background! Fast hardware encoding active 🚀'),
            ),
          ],
        ),
        backgroundColor: GamerTheme.cardDark,
        duration: Duration(seconds: 4),
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
            Text(
              'Publish Video',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
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
              onPressed: _isPublishing ? null : _handlePublish,
              style: ElevatedButton.styleFrom(
                backgroundColor: GamerTheme.accentBlue,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text(
                'Publish',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
            // User Header Row (Facebook Style)
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
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
                      Text(
                        'MAX 3 MIN',
                        style: TextStyle(
                          color: GamerTheme.neonGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Video Caption Input
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

            // Video Upload Card / Preview
            _videoFile == null
                ? InkWell(
                    onTap: _showPickerBottomSheet,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      decoration: BoxDecoration(
                        color: GamerTheme.cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: GamerTheme.accentBlue.withOpacity(0.6),
                          width: 1.5,
                          style: BorderStyle.solid,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: GamerTheme.accentBlue.withOpacity(0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: GamerTheme.blueOrangeGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: GamerTheme.accentBlue.withOpacity(0.4),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.video_library_rounded, color: Colors.white, size: 36),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Select Video to Publish',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Supports MP4, MOV up to 3 minutes (180s)',
                            style: TextStyle(
                              color: GamerTheme.textMuted,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: GamerTheme.neonGreen.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: GamerTheme.neonGreen.withOpacity(0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt_rounded, color: GamerTheme.neonGreen, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Fast GPU Hardware Compression (1000MB -> 80MB)',
                                  style: TextStyle(
                                    color: GamerTheme.neonGreen,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
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
                      border: Border.all(color: GamerTheme.neonGreen, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_fileSizeMB.toStringAsFixed(1)} MB • Capped to 3 Minutes',
                                      style: const TextStyle(
                                        color: GamerTheme.neonGreen,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.change_circle_rounded, color: GamerTheme.accentBlue, size: 26),
                                tooltip: 'Change Video',
                                onPressed: _showPickerBottomSheet,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: GamerTheme.redAccent, size: 24),
                                tooltip: 'Remove Video',
                                onPressed: () {
                                  setState(() {
                                    _videoFile = null;
                                    _fileSizeMB = 0.0;
                                    _videoFileName = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_user_rounded, color: GamerTheme.neonGreen, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Ready for Ultrafast Hardware Encoding (720p 30fps)',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

            const SizedBox(height: 20),

            // Game Category Tag Selector
            const Text(
              'Select Game Tag',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
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

            // Bottom Publish Button (Facebook Style)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: Container(
                decoration: BoxDecoration(
                  gradient: GamerTheme.blueOrangeGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: GamerTheme.accentBlue.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isPublishing ? null : _handlePublish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                  label: const Text(
                    'Publish Video (Max 3 Min)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
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
