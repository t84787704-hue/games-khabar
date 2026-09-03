import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/news_model.dart';
import '../services/firestore_service.dart';
import '../widgets/app_image_view.dart';
import '../utils/admin_security.dart';
import '../services/notification_service.dart';
import '../services/translation_service.dart';
import '../constants/game_categories.dart';

/// Helper function to extract 11-char YouTube video ID from various YouTube URL formats or direct ID
String? extractYoutubeId(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  String cleanUrl = url.trim();

  // 1. Direct 11-character video ID
  final directIdRegex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
  if (directIdRegex.hasMatch(cleanUrl)) {
    return cleanUrl;
  }

  // 2. Remove ?si= or &si= parameter
  if (cleanUrl.contains('?si=') || cleanUrl.contains('&si=')) {
    cleanUrl = cleanUrl.replaceAll(RegExp(r'[?&]si=[^&#]+'), '');
  }

  // 3. Extract ID using RegExp supporting youtu.be/, watch?v=, shorts/, embed/, live/, etc.
  final regExp = RegExp(
    r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=|shorts\/|live\/)|(?:v=))([a-zA-Z0-9_-]{11})',
    caseSensitive: false,
  );
  final match = regExp.firstMatch(cleanUrl);
  if (match != null && match.group(1) != null) {
    return match.group(1);
  }

  // Fallback pattern matching v= or youtu.be/
  final fallbackRegExp = RegExp(
    r'(?:v=|youtu\.be\/)([a-zA-Z0-9_-]{11})',
    caseSensitive: false,
  );
  final fallbackMatch = fallbackRegExp.firstMatch(cleanUrl);
  return fallbackMatch?.group(1);
}

/// Validates whether the given string is a valid YouTube URL or 11-char ID
bool isValidYoutubeUrl(String? url) {
  if (url == null || url.trim().isEmpty) return false;
  final id = extractYoutubeId(url);
  return id != null && id.length == 11;
}

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
  late final TextEditingController _videoUrlController;
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  late String _selectedCategory;
  bool _isFeatured = false;
  bool _isPublishing = false;
  String _publishingStatus = '';
  bool _isProcessingImage = false;

  // Selected image representation (base64 string and bytes for preview)
  String? _base64ImageUrl;
  Uint8List? _localImageBytes;

  List<String> get availableCategories =>
      gameCategories.where((cat) => cat != 'All').toList();

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

    // Security check: only allow authorized admin
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isAdminUser()) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFFFF4655),
              behavior: SnackBarBehavior.floating,
              content: Text(
                'Access Denied - Not Admin',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
      }
    });

    final item = widget.editItem;
    _titleController = TextEditingController(text: item?.title ?? '');
    _descController = TextEditingController(text: item?.description ?? '');
    _videoUrlController = TextEditingController(text: item?.videoUrl ?? '');

    if (item != null && item.imageUrl.isNotEmpty) {
      _base64ImageUrl = item.imageUrl;
      if (AppImageView.isBase64(item.imageUrl)) {
        _localImageBytes = AppImageView.decodeBase64(item.imageUrl);
      }
    }

    final categoriesList = availableCategories;
    if (item != null && item.category.isNotEmpty) {
      _selectedCategory = item.category;
    } else {
      _selectedCategory = categoriesList.isNotEmpty ? categoriesList.first : 'Open World';
    }
    _isFeatured = item?.isFeatured ?? false;
  }

  Future<void> _pickAndCompressImage(ImageSource source) async {
    try {
      setState(() {
        _isProcessingImage = true;
      });

      // Compress to 600x600 with optimal JPEG quality
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );

      if (pickedFile == null) {
        setState(() {
          _isProcessingImage = false;
        });
        return;
      }

      final bytes = await pickedFile.readAsBytes();
      final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      setState(() {
        _localImageBytes = bytes;
        _base64ImageUrl = base64String;
        _isProcessingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cardDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: neonGreen, width: 1),
            ),
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: neonGreen, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Image compressed (600x600) & ready! (${(bytes.length / 1024).toStringAsFixed(1)} KB)',
                  style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessingImage = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: alertRed,
            content: Text('Failed to pick image: $e', style: const TextStyle(color: Colors.white)),
          ),
        );
      }
    }
  }

  void _removeSelectedImage() {
    setState(() {
      _localImageBytes = null;
      _base64ImageUrl = null;
    });
  }

  Future<void> _submitNews() async {
    if (!_formKey.currentState!.validate()) return;

    // Default image if none uploaded
    final finalImageUrl = (_base64ImageUrl != null && _base64ImageUrl!.isNotEmpty)
        ? _base64ImageUrl!
        : 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=600&q=80';

    final rawVideoUrl = _videoUrlController.text.trim();
    String videoUrl = '';
    if (rawVideoUrl.isNotEmpty) {
      final ytId = extractYoutubeId(rawVideoUrl);
      if (ytId != null) {
        videoUrl = 'https://www.youtube.com/watch?v=$ytId';
      } else {
        videoUrl = rawVideoUrl;
      }
    }

    setState(() {
      _isPublishing = true;
      _publishingStatus = 'Translating to 7 languages...';
    });

    try {
      final title = _titleController.text.trim();
      final description = _descController.text.trim();

      // Auto-translate title and description into 7 target languages:
      // Roman, English, Hindi, Urdu, Bengali, Arabic, Chinese
      final titleMap = await TranslationService.translateTo7Languages(title);
      final contentMap = await TranslationService.translateTo7Languages(description);

      if (mounted) {
        setState(() {
          _publishingStatus = 'Saving to Firestore...';
        });
      }

      final payload = {
        'title': titleMap,
        'content': contentMap,
        'description': contentMap,
        'category': _selectedCategory,
        'imageUrl': finalImageUrl,
        'videoUrl': videoUrl, // Empty string if empty
        'isFree': _selectedCategory.toLowerCase().contains('free'),
        'isFeatured': _isFeatured,
      };

      if (isEditing) {
        await _firestoreService.updateNews(widget.editItem!.id, payload);
      } else {
        final newNewsId = await _firestoreService.addNews(payload);
        // Send FCM notification to topic 'all_news'
        try {
          await NotificationService().sendNewsNotification(
            newsId: newNewsId,
            title: titleMap['roman'] ?? title,
            description: contentMap['roman'] ?? description,
            category: _selectedCategory,
            imageUrl: finalImageUrl,
          );
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cardDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: neonGreen, width: 1),
            ),
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: neonGreen, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEditing
                        ? 'Khabar Updated in 7 Languages! 🎮'
                        : 'Khabar Published in 7 Languages! 🎉',
                    style: TextStyle(color: textWhite, fontWeight: FontWeight.bold),
                  ),
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
          _publishingStatus = '';
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _localImageBytes != null || (_base64ImageUrl != null && _base64ImageUrl!.isNotEmpty);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: cardDark,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textWhite, size: 20),
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
              style: TextStyle(
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
              // 7-Language Auto-Translate Banner
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: neonGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: neonGreen.withOpacity(0.4), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.g_translate_rounded, color: neonGreen, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Multi-Language 7X Auto-Publish',
                          style: TextStyle(
                            color: neonGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Write only in Roman (or English). On publish, it will automatically translate to 7 languages and save directly to Firestore for instant display.',
                      style: TextStyle(color: textGray, fontSize: 11.5, height: 1.35),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: const [
                        _LangPill(label: 'Roman', flag: '🇵🇰'),
                        _LangPill(label: 'English', flag: '🇬🇧'),
                        _LangPill(label: 'हिंदी', flag: '🇮🇳'),
                        _LangPill(label: 'اردو', flag: '🇵🇰'),
                        _LangPill(label: 'বাংলা', flag: '🇧🇩'),
                        _LangPill(label: 'العربية', flag: '🇸🇦'),
                        _LangPill(label: '中文', flag: '🇨🇳'),
                      ],
                    ),
                  ],
                ),
              ),

              // Title Field
              Text(
                'News Title (Heading in Roman / English)',
                style: TextStyle(color: textWhite, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                maxLength: 200,
                style: TextStyle(color: textWhite, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. BGMI 3.4 Update Release Date & Features',
                  hintStyle: TextStyle(color: textGray, fontSize: 13),
                  filled: true,
                  fillColor: cardDark,
                  counterStyle: TextStyle(color: textGray, fontSize: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: neonGreen, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Title is required';
                  }
                  if (val.trim().length > 200) {
                    return 'Title cannot exceed 200 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // Category Dropdown
              Text(
                'Category',
                style: TextStyle(color: textWhite, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: {
                  ...gameCategories.where((cat) => cat != 'All'),
                  if (_selectedCategory.isNotEmpty) _selectedCategory,
                }.contains(_selectedCategory)
                    ? _selectedCategory
                    : (availableCategories.isNotEmpty ? availableCategories.first : 'Open World'),
                dropdownColor: cardDark,
                isExpanded: true,
                icon: Icon(Icons.keyboard_arrow_down, color: neonGreen),
                style: TextStyle(
                  color: textWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: cardDark,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: neonGreen, width: 1.5),
                  ),
                ),
                items: {
                  ...gameCategories.where((cat) => cat != 'All'),
                  if (_selectedCategory.isNotEmpty) _selectedCategory,
                }.map((cat) {
                  return DropdownMenuItem<String>(
                    value: cat,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: neonGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            cat,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: textWhite, fontSize: 14),
                          ),
                        ),
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
                onSaved: (val) {
                  if (val != null) {
                    _selectedCategory = val;
                  }
                },
              ),
              const SizedBox(height: 18),

              // Mark as Featured Switch
              Container(
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isFeatured ? neonGreen : borderDark,
                    width: _isFeatured ? 1.5 : 1,
                  ),
                ),
                child: SwitchListTile(
                  activeColor: neonGreen,
                  activeTrackColor: neonGreen.withOpacity(0.3),
                  inactiveThumbColor: textGray,
                  inactiveTrackColor: cardDark2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  secondary: Icon(
                    _isFeatured ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: _isFeatured ? neonGreen : textGray,
                    size: 24,
                  ),
                  title: Text(
                    'Mark as Featured - Show on Top Banner',
                    style: TextStyle(
                      color: textWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Displays this news in the top big hero card on the home screen',
                    style: TextStyle(
                      color: textGray,
                      fontSize: 11,
                    ),
                  ),
                  value: _isFeatured,
                  onChanged: (val) {
                    setState(() {
                      _isFeatured = val;
                    });
                  },
                ),
              ),
              const SizedBox(height: 22),

              // Image Upload Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.image_outlined, color: neonGreen, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'News Cover Image (Compressed 600x600)',
                        style: TextStyle(color: textWhite, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (hasImage && !_isProcessingImage)
                    GestureDetector(
                      onTap: _removeSelectedImage,
                      child: Text(
                        'Remove',
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

              // Upload Buttons Container
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderDark),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Button 1: Gallery
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textWhite,
                                side: BorderSide(color: borderDark),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                backgroundColor: cardDark2,
                              ),
                              onPressed: _isProcessingImage
                                  ? null
                                  : () => _pickAndCompressImage(ImageSource.gallery),
                              icon: Icon(Icons.photo_library_rounded, color: neonGreen, size: 18),
                              label: const Text(
                                'Gallery',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Button 2: Camera
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textWhite,
                                side: BorderSide(color: borderDark),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                backgroundColor: cardDark2,
                              ),
                              onPressed: _isProcessingImage
                                  ? null
                                  : () => _pickAndCompressImage(ImageSource.camera),
                              icon: Icon(Icons.camera_alt_rounded, color: neonGreen, size: 18),
                              label: const Text(
                                'Camera',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_isProcessingImage) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(neonGreen),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Compressing to 600x600 base64...',
                            style: TextStyle(color: textGray, fontSize: 12),
                          ),
                        ],
                      ),
                    ],

                    // Image Preview
                    if (hasImage && !_isProcessingImage) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          color: cardDark2,
                          child: _localImageBytes != null
                              ? Image.memory(
                                  _localImageBytes!,
                                  fit: BoxFit.cover,
                                )
                              : AppImageView(
                                  imageUrl: _base64ImageUrl ?? '',
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Video (Optional) Section
              Row(
                children: const [
                  Icon(Icons.video_library_rounded, color: Color(0xFFFF4655), size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Video (Optional)',
                    style: TextStyle(color: textWhite, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _videoUrlController,
                style: TextStyle(color: textWhite, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. https://youtu.be/xxx or watch?v=xxx or Video ID',
                  hintStyle: TextStyle(color: textGray, fontSize: 13),
                  helperText: 'Supports youtu.be, youtube.com, Shorts, or 11-character Video ID',
                  helperStyle: TextStyle(color: textGray, fontSize: 11),
                  prefixIcon: Icon(Icons.link_rounded, color: neonGreen, size: 20),
                  filled: true,
                  fillColor: cardDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFF4655), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return null; // Optional
                  }
                  if (!isValidYoutubeUrl(val)) {
                    return 'Please enter a valid YouTube URL or 11-char Video ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Description Multi-line
              Text(
                'Description / Content (in Roman / English)',
                style: TextStyle(color: textWhite, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 6,
                style: TextStyle(color: textWhite, fontSize: 14, height: 1.4),
                decoration: InputDecoration(
                  hintText: 'Enter full news details in Roman or English (auto-translates to 7 languages)...',
                  hintStyle: TextStyle(color: textGray, fontSize: 13),
                  filled: true,
                  fillColor: cardDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: neonGreen, width: 1.5),
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
                child: ElevatedButton(
                  onPressed: (_isPublishing || _isProcessingImage) ? null : _submitNews,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: neonGreen,
                    foregroundColor: const Color(0xFF05080D),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isPublishing
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF05080D)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _publishingStatus.isNotEmpty
                                  ? _publishingStatus
                                  : 'Translating to 7 languages...',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF05080D),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isEditing ? Icons.check_circle_outline_rounded : Icons.publish_rounded,
                              color: const Color(0xFF05080D),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isEditing ? 'Update & Save Changes' : 'Save & Publish Khabar',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
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

class _LangPill extends StatelessWidget {
  final String label;
  final String flag;

  const _LangPill({required this.label, required this.flag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2E2E38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(flag, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF00FF88),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
