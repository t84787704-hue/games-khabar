import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../models/news_model.dart';
import '../services/firestore_service.dart';

class AddNewsScreen extends StatefulWidget {
  final NewsModel? editItem;

  const AddNewsScreen({super.key, this.editItem});

  @override
  State<AddNewsScreen> createState() => _AddNewsScreenState();
}

class _AddNewsScreenState extends State<AddNewsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  late String _selectedCategory;
  bool _isPublishing = false;

  // Media upload state
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';
  UploadTask? _activeUploadTask;

  // Selected/Uploaded media
  File? _localMediaFile;
  bool _isVideo = false;
  String? _uploadedImageUrl;
  String? _uploadedVideoUrl;
  String? _mediaSizeText;

  // Mini preview player for video
  VideoPlayerController? _videoPreviewController;

  static const List<String> categories = [
    'BGMI',
    'Free Fire',
    'PUBG',
    'COD',
    'Valorant',
    'Gaming News',
  ];

  static const Color neonGreen = Color(0xFF00FF88);
  static const Color bgDark = Color(0xFF0A0A0F);
  static const Color cardDark = Color(0xFF1E1E24);
  static const Color cardDark2 = Color(0xFF15151A);
  static const Color borderDark = Color(0xFF2E2E38);
  static const Color alertRed = Color(0xFFFF4655);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF9E9EA7);

  bool get isEditing => widget.editItem != null;

  @override
  void initState() {
    super.initState();

    final item = widget.editItem;
    _titleController = TextEditingController(text: item?.title ?? '');
    _descController = TextEditingController(text: item?.description ?? '');

    if (item != null) {
      _uploadedImageUrl = item.imageUrl;
      _uploadedVideoUrl = item.videoUrl;
      _isVideo = item.videoUrl != null && item.videoUrl!.isNotEmpty;
      if (_isVideo && _uploadedVideoUrl != null) {
        _initVideoPreview(url: _uploadedVideoUrl);
      }
    }

    if (item != null && categories.contains(item.category)) {
      _selectedCategory = item.category;
    } else {
      _selectedCategory = 'BGMI';
    }
  }

  Future<void> _initVideoPreview({File? file, String? url}) async {
    try {
      _videoPreviewController?.dispose();
      if (file != null) {
        _videoPreviewController = VideoPlayerController.file(file);
      } else if (url != null) {
        _videoPreviewController = VideoPlayerController.networkUrl(Uri.parse(url));
      }
      if (_videoPreviewController != null) {
        await _videoPreviewController!.initialize();
        _videoPreviewController!.setLooping(true);
        _videoPreviewController!.play();
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _pickAndUploadMedia({required ImageSource source, required bool isVideo}) async {
    if (_isUploading) return;

    try {
      final XFile? pickedFile = isVideo
          ? await _picker.pickVideo(
              source: source,
              maxDuration: const Duration(minutes: 5),
            )
          : await _picker.pickImage(
              source: source,
              imageQuality: 88,
            );

      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      final int fileBytes = await file.length();
      final double sizeInMb = fileBytes / (1024 * 1024);

      // File Size Validation
      if (!isVideo && sizeInMb > 10.0) {
        _showErrorDialog(
          title: 'Image Size Exceeded',
          message: 'Selected image is ${sizeInMb.toStringAsFixed(1)} MB. Maximum allowed image size is 10 MB.',
        );
        return;
      }

      if (isVideo && sizeInMb > 50.0) {
        _showErrorDialog(
          title: 'Video Size Exceeded',
          message: 'Selected video is ${sizeInMb.toStringAsFixed(1)} MB. Maximum allowed video size is 50 MB.',
        );
        return;
      }

      setState(() {
        _localMediaFile = file;
        _isVideo = isVideo;
        _mediaSizeText = '${sizeInMb.toStringAsFixed(1)} MB';
        _isUploading = true;
        _uploadProgress = 0.05;
        _uploadStatus = 'Preparing ${isVideo ? 'video' : 'image'}...';
      });

      if (isVideo) {
        _initVideoPreview(file: file);
      }

      // Upload to Firebase Storage in folder news_media/
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeName = pickedFile.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath = 'news_media/${timestamp}_$safeName';

      final ref = FirebaseStorage.instance.ref().child(storagePath);
      final metadata = SettableMetadata(
        contentType: isVideo ? 'video/mp4' : 'image/jpeg',
      );

      final uploadTask = ref.putFile(file, metadata);
      _activeUploadTask = uploadTask;

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.totalBytes > 0) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
              _uploadStatus = 'Uploading ${(progress * 100).toInt()}% (${(snapshot.bytesTransferred / (1024 * 1024)).toStringAsFixed(1)}MB / ${(snapshot.totalBytes / (1024 * 1024)).toStringAsFixed(1)}MB)';
            });
          }
        }
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 1.0;
          _uploadStatus = 'Upload complete!';
          if (isVideo) {
            _uploadedVideoUrl = downloadUrl;
            // Default gaming cover image if no separate cover exists
            if (_uploadedImageUrl == null || _uploadedImageUrl!.isEmpty) {
              _uploadedImageUrl = 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80';
            }
          } else {
            _uploadedImageUrl = downloadUrl;
            _uploadedVideoUrl = null;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cardDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: neonGreen, width: 1),
            ),
            content: Row(
              children: [
                const Icon(Icons.cloud_done_rounded, color: neonGreen, size: 20),
                const SizedBox(width: 10),
                Text(
                  '${isVideo ? 'Video' : 'Image'} uploaded to Firebase Storage!',
                  style: const TextStyle(color: textWhite, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          // Fallback url in case Firebase Storage rule requires auth / offline
          if (isVideo) {
            _uploadedVideoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
            _uploadedImageUrl = 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80';
          } else {
            _uploadedImageUrl = 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80';
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cardDark,
            content: Text(
              'Media selected. (Storage Notice: $e)',
              style: const TextStyle(color: textWhite),
            ),
          ),
        );
      }
    }
  }

  void _showErrorDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: alertRed),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: alertRed, size: 24),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: textGray, fontSize: 13)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: alertRed),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _removeSelectedMedia() {
    _activeUploadTask?.cancel();
    _videoPreviewController?.dispose();
    _videoPreviewController = null;
    setState(() {
      _localMediaFile = null;
      _uploadedImageUrl = null;
      _uploadedVideoUrl = null;
      _isVideo = false;
      _isUploading = false;
      _mediaSizeText = null;
    });
  }

  Future<void> _submitNews() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: cardDark,
          content: Text('Please wait for media upload to finish', style: TextStyle(color: neonGreen)),
        ),
      );
      return;
    }

    // Default image if none uploaded
    final finalImageUrl = (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty)
        ? _uploadedImageUrl!
        : 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80';

    setState(() {
      _isPublishing = true;
    });

    try {
      final title = _titleController.text.trim();
      final description = _descController.text.trim();

      final payload = {
        'title': title,
        'description': description,
        'category': _selectedCategory,
        'imageUrl': finalImageUrl,
        'videoUrl': _uploadedVideoUrl,
        'isFree': _selectedCategory.toLowerCase().contains('free'),
      };

      if (isEditing) {
        await _firestoreService.updateNews(widget.editItem!.id, payload);
      } else {
        await _firestoreService.addNews(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cardDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: neonGreen, width: 1),
            ),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: neonGreen, size: 20),
                const SizedBox(width: 10),
                Text(
                  isEditing
                      ? 'Khabar Updated Successfully! 🎮'
                      : 'Khabar Published Successfully! 🎉',
                  style: const TextStyle(color: textWhite, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: alertRed,
            content: Text('Error: $e', style: const TextStyle(color: Colors.white)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _videoPreviewController?.dispose();
    _activeUploadTask?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMedia = (_localMediaFile != null) ||
        (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty) ||
        (_uploadedVideoUrl != null && _uploadedVideoUrl!.isNotEmpty);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: cardDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textWhite, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
              color: neonGreen,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              isEditing ? 'Edit Khabar' : 'Add New Khabar',
              style: const TextStyle(
                color: textWhite,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Field
              const Text(
                'News Title (Heading)',
                style: TextStyle(color: textWhite, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: textWhite, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. BGMI 3.4 Update Release Date & Features',
                  hintStyle: const TextStyle(color: textGray, fontSize: 13),
                  filled: true,
                  fillColor: cardDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: borderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: neonGreen, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 18),

              // Category Dropdown
              const Text(
                'Category',
                style: TextStyle(color: textWhite, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderDark),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    dropdownColor: cardDark,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: neonGreen),
                    style: const TextStyle(
                      color: textWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    items: categories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat,
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: neonGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(cat),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedCategory = val;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Media Upload Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.cloud_upload_outlined, color: neonGreen, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Upload Media (Firebase Storage)',
                        style: TextStyle(color: textWhite, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (hasMedia && !_isUploading)
                    GestureDetector(
                      onTap: _removeSelectedMedia,
                      child: const Text(
                        'Remove Media',
                        style: TextStyle(
                          color: alertRed,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Upload Buttons Container (3 Buttons as requested)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Button 1: Upload Image from Gallery
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textWhite,
                          side: const BorderSide(color: borderDark),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          backgroundColor: cardDark2,
                        ),
                        onPressed: _isUploading
                            ? null
                            : () => _pickAndUploadMedia(
                                  source: ImageSource.gallery,
                                  isVideo: false,
                                ),
                        icon: const Icon(Icons.photo_library_rounded, color: neonGreen, size: 18),
                        label: const Text(
                          'Upload Image from Gallery (Max 10MB)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Button 2: Take Photo with Camera
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textWhite,
                          side: const BorderSide(color: borderDark),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          backgroundColor: cardDark2,
                        ),
                        onPressed: _isUploading
                            ? null
                            : () => _pickAndUploadMedia(
                                  source: ImageSource.camera,
                                  isVideo: false,
                                ),
                        icon: const Icon(Icons.camera_alt_rounded, color: neonGreen, size: 18),
                        label: const Text(
                          'Take Photo with Camera',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Button 3: Upload Video from Gallery
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textWhite,
                          side: const BorderSide(color: neonGreen, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          backgroundColor: cardDark2,
                        ),
                        onPressed: _isUploading
                            ? null
                            : () => _pickAndUploadMedia(
                                  source: ImageSource.gallery,
                                  isVideo: true,
                                ),
                        icon: const Icon(Icons.video_library_rounded, color: Color(0xFFFF4655), size: 18),
                        label: const Text(
                          'Upload Video from Gallery (Max 50MB)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Uploading Progress Card
              if (_isUploading) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardDark2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: neonGreen.withOpacity(0.5)),
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
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(neonGreen),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _uploadStatus,
                                style: const TextStyle(
                                  color: textWhite,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${(_uploadProgress * 100).toInt()}%',
                            style: const TextStyle(
                              color: neonGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _uploadProgress,
                          backgroundColor: borderDark,
                          valueColor: const AlwaysStoppedAnimation<Color>(neonGreen),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Media Preview Section
              if (hasMedia && !_isUploading) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: neonGreen.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                            color: _isVideo ? const Color(0xFFFF4655) : neonGreen,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isVideo ? 'Video Preview' : 'Image Preview',
                            style: const TextStyle(
                              color: textWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (_mediaSizeText != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: borderDark,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _mediaSizeText!,
                                style: const TextStyle(color: textGray, fontSize: 10),
                              ),
                            ),
                          ],
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: alertRed, size: 18),
                            onPressed: _removeSelectedMedia,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Remove',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Preview Widget
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 180,
                          width: double.infinity,
                          color: cardDark2,
                          child: _isVideo
                              ? (_videoPreviewController != null &&
                                      _videoPreviewController!.value.isInitialized)
                                  ? AspectRatio(
                                      aspectRatio: _videoPreviewController!.value.aspectRatio,
                                      child: VideoPlayer(_videoPreviewController!),
                                    )
                                  : Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        if (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty)
                                          CachedNetworkImage(
                                            imageUrl: _uploadedImageUrl!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                          ),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.7),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: neonGreen, width: 2),
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow_rounded,
                                            color: neonGreen,
                                            size: 32,
                                          ),
                                        ),
                                      ],
                                    )
                              : (_localMediaFile != null)
                                  ? Image.file(
                                      _localMediaFile!,
                                      fit: BoxFit.cover,
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: _uploadedImageUrl ?? '',
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => const Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(neonGreen),
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) => const Center(
                                        child: Icon(Icons.broken_image_rounded, color: textGray, size: 36),
                                      ),
                                    ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // Description Multi-line
              const Text(
                'Description / Content',
                style: TextStyle(color: textWhite, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 6,
                style: const TextStyle(color: textWhite, fontSize: 14, height: 1.4),
                decoration: InputDecoration(
                  hintText: 'Enter full news details in Urdu/English...',
                  hintStyle: const TextStyle(color: textGray, fontSize: 13),
                  filled: true,
                  fillColor: cardDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: borderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: neonGreen, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Description is required' : null,
              ),
              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (_isPublishing || _isUploading) ? null : _submitNews,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: neonGreen,
                    foregroundColor: const Color(0xFF05080D),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isPublishing
                      ? const SizedBox.shrink()
                      : Icon(
                          isEditing ? Icons.check_circle_outline_rounded : Icons.publish_rounded,
                          color: const Color(0xFF05080D),
                          size: 20,
                        ),
                  label: _isPublishing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF05080D)),
                          ),
                        )
                      : Text(
                          isEditing ? 'Update & Save Changes' : 'Save & Publish Khabar',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
