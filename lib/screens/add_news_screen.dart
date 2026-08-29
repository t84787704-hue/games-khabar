import 'package:flutter/material.dart';
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
  late final TextEditingController _imageUrlController;
  final FirestoreService _firestoreService = FirestoreService();

  late String _selectedCategory;
  bool _isLoading = false;

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
    _imageUrlController = TextEditingController(
      text: item?.imageUrl ??
          'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80',
    );

    if (item != null && categories.contains(item.category)) {
      _selectedCategory = item.category;
    } else {
      _selectedCategory = 'BGMI';
    }
  }

  Future<void> _submitNews() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final title = _titleController.text.trim();
      final description = _descController.text.trim();
      final imageUrl = _imageUrlController.text.trim().isNotEmpty
          ? _imageUrlController.text.trim()
          : 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80';

      if (isEditing) {
        await _firestoreService.updateNews(widget.editItem!.id, {
          'title': title,
          'description': description,
          'category': _selectedCategory,
          'imageUrl': imageUrl,
          'isFree': _selectedCategory.toLowerCase().contains('free'),
        });
      } else {
        await _firestoreService.addNews({
          'title': title,
          'description': description,
          'category': _selectedCategory,
          'imageUrl': imageUrl,
          'isFree': _selectedCategory.toLowerCase().contains('free'),
        });
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
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 18),

              // Image URL Field
              const Text(
                'Image URL',
                style: TextStyle(color: textWhite, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _imageUrlController,
                style: const TextStyle(color: textWhite, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'https://...',
                  hintStyle: const TextStyle(color: textGray, fontSize: 13),
                  filled: true,
                  fillColor: cardDark,
                  prefixIcon: const Icon(Icons.image_outlined, color: textGray, size: 20),
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
                onChanged: (_) => setState(() {}),
              ),
              if (_imageUrlController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 130,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cardDark2,
                      border: Border.all(color: borderDark),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Image.network(
                      _imageUrlController.text.trim(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image_rounded, color: textGray, size: 20),
                            SizedBox(width: 8),
                            Text('Preview unavailable for this URL',
                                style: TextStyle(color: textGray, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
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
                  onPressed: _isLoading ? null : _submitNews,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: neonGreen,
                    foregroundColor: const Color(0xFF05080D),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isLoading
                      ? const SizedBox.shrink()
                      : Icon(
                          isEditing ? Icons.check_circle_outline_rounded : Icons.publish_rounded,
                          color: const Color(0xFF05080D),
                          size: 20,
                        ),
                  label: _isLoading
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
