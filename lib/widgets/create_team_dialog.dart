import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/gamer_theme.dart';
import '../services/gamer_auth_service.dart';
import '../services/team_service.dart';

class CreateTeamDialog extends StatefulWidget {
  const CreateTeamDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateTeamDialog(),
    );
  }

  @override
  State<CreateTeamDialog> createState() => _CreateTeamDialogState();
}

class _CreateTeamDialogState extends State<CreateTeamDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _reqController = TextEditingController();

  String _selectedGame = 'BGMI';
  File? _logoFile;
  bool _isLoading = false;

  final List<String> _games = ['BGMI', 'Free Fire', 'PUBG', 'COD'];

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    _descController.dispose();
    _reqController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _logoFile = File(picked.path));
    }
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    final currentGamer = GamerAuthService().currentGamer;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('براہ کرم پہلے لاگ ان کریں')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final leaderName = currentGamer?.displayName ??
        currentGamer?.username ??
        currentUser.displayName ??
        'Team Leader';
    final leaderAvatar = currentGamer?.photoUrl ?? currentUser.photoURL ?? '';

    final teamId = await TeamService().createTeam(
      name: _nameController.text.trim(),
      tag: _tagController.text.trim().toUpperCase(),
      logoFile: _logoFile,
      game: _selectedGame,
      description: _descController.text.trim(),
      requirements: _reqController.text.trim(),
      leaderId: currentUser.uid,
      leaderName: leaderName,
      leaderAvatar: leaderAvatar,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (teamId != null) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 ٹیم "${_nameController.text.trim()}" کامیابی سے بن گئی!'),
            backgroundColor: const Color(0xFF00FF88),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ٹیم بنانے میں خرابی پیش آئی۔ دوبارہ کوشش کریں۔'),
            backgroundColor: Color(0xFFFF4655),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF131A29),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF2A3447), width: 1.5)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B00).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('🛡️', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CREATE NEW TEAM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'اپنی ای اسپورٹس ٹیم بنائیں اور چیلنجز کھیلیں',
                          style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF1E293B), height: 1),
              const SizedBox(height: 16),

              // Logo Picker
              Center(
                child: Column(
                  children: [
                    InkWell(
                      onTap: _pickLogo,
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1A2234),
                          border: Border.all(color: const Color(0xFFFF6B00), width: 2),
                          image: _logoFile != null
                              ? DecorationImage(image: FileImage(_logoFile!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _logoFile == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_rounded, color: Color(0xFFFF6B00), size: 26),
                                  SizedBox(height: 2),
                                  Text('Logo', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'ٹیم کا لوگو منتخب کریں (اختیاری)',
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Team Name Field
              const Text(
                'ٹیم کا نام (Team Name) *',
                style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'مثلاً: Thunder Strikers',
                  hintStyle: const TextStyle(color: Color(0xFF555E6D), fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF161F2E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2A3447))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2A3447))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFFF6B00))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'ٹیم کا نام لکھنا لازمی ہے';
                  if (val.trim().length < 3) return 'کم از کم 3 حروف کا نام لکھیں';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Team Tag Field (4 chars e.g. GIDN)
              const Text(
                'ٹیم کا ٹیگ (Tag - 4 Letters) *',
                style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _tagController,
                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(4),
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                ],
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'مثلاً: GIDN, SOUL, GODL',
                  hintStyle: const TextStyle(color: Color(0xFF555E6D), fontSize: 13, letterSpacing: 0),
                  filled: true,
                  fillColor: const Color(0xFF161F2E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2A3447))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2A3447))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFFF6B00))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'ٹیم کا 4 حرفی ٹیگ لازمی ہے';
                  if (val.trim().length != 4) return 'ٹیگ لازمی 4 حروف پر مشتمل ہو (مثلاً GIDN)';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Game Selection (BGMI, Free Fire, PUBG, COD)
              const Text(
                'گیم کا انتخاب (Game) *',
                style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _games.map((g) {
                  final isSel = _selectedGame == g;
                  return ChoiceChip(
                    label: Text(g, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    selected: isSel,
                    selectedColor: const Color(0xFFFF6B00),
                    backgroundColor: const Color(0xFF161F2E),
                    onSelected: (val) {
                      if (val) setState(() => _selectedGame = g);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Team Description
              const Text(
                'ٹیم کی تفصیل (Description)',
                style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'ہماری ٹیم سخت محنت اور ای اسپورٹس ٹورنامنٹس میں حصہ لیتی ہے...',
                  hintStyle: const TextStyle(color: Color(0xFF555E6D), fontSize: 12.5),
                  filled: true,
                  fillColor: const Color(0xFF161F2E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2A3447))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2A3447))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFFF6B00))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),

              // Requirements
              const Text(
                'شرائط (Requirements)',
                style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reqController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'K/D 3.5+, Ace Rank, شام 7 بجے پریکٹس لازمی...',
                  hintStyle: const TextStyle(color: Color(0xFF555E6D), fontSize: 12.5),
                  filled: true,
                  fillColor: const Color(0xFF161F2E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2A3447))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2A3447))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFFF6B00))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 22),

              // Create Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleCreate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.shield_rounded, color: Colors.black),
                  label: Text(
                    _isLoading ? 'Creating Team...' : 'CREATE TEAM (ٹیم بنائیں)',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
