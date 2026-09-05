import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_user_model.dart';
import '../services/gamer_auth_service.dart';
import '../widgets/gamer_avatar.dart';
import 'gamer_main_navigation_screen.dart';

class CreateGamerIdScreen extends StatefulWidget {
  final bool isEditing;
  final GamerUser? existingUser;

  const CreateGamerIdScreen({
    super.key,
    this.isEditing = false,
    this.existingUser,
  });

  @override
  State<CreateGamerIdScreen> createState() => _CreateGamerIdScreenState();
}

class _CreateGamerIdScreenState extends State<CreateGamerIdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _rankController = TextEditingController();

  String _selectedGame = 'BGMI';
  String _photoUrl = '';
  File? _pickedImageFile;
  bool _isSaving = false;

  // Live username availability check state
  Timer? _debounceTimer;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String _usernameFeedback = '';

  final List<String> _rankSuggestions = [
    'Ace',
    'Conqueror',
    'Heroic',
    'Grandmaster',
    'Radiant',
    'Immortal',
    'Diamond',
    'Legendary',
  ];

  final List<String> _avatarPresets = [
    'https://images.unsplash.com/photo-1566492031773-4f4e44671857?w=150&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=150&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=150&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1628157582853-a796fa650a6a?w=150&auto=format&fit=crop&q=80',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingUser != null) {
      final u = widget.existingUser!;
      _usernameController.text = u.username;
      _displayNameController.text = u.displayName;
      _bioController.text = u.bio;
      _selectedGame = GamerTheme.favoriteGames.contains(u.favoriteGame) ? u.favoriteGame : 'BGMI';
      _rankController.text = u.rank;
      _photoUrl = u.photoUrl;
      _isUsernameAvailable = true;
    } else {
      final fbUser = GamerAuthService().currentUser;
      if (fbUser != null) {
        _displayNameController.text = fbUser.displayName ?? '';
        if (fbUser.photoURL != null && fbUser.photoURL!.isNotEmpty) {
          _photoUrl = fbUser.photoURL!;
        }
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    _rankController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounceTimer?.cancel();
    final clean = value.toLowerCase().trim();

    if (clean.isEmpty) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = null;
        _usernameFeedback = '';
      });
      return;
    }

    final regExp = RegExp(r'^[a-z0-9_]{3,15}$');
    if (!regExp.hasMatch(clean)) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameFeedback = '3-15 characters, lowercase letters, numbers & _ only (no spaces)';
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameFeedback = 'Checking availability...';
    });

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final available = await GamerAuthService().isUsernameAvailable(
        clean,
        currentUid: widget.existingUser?.uid ?? GamerAuthService().currentUid,
      );

      if (!mounted) return;
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = available;
        _usernameFeedback = available ? 'Username is available! 🎉' : 'Username is already taken! ❌';
      });
    });
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );

      if (picked != null) {
        setState(() {
          _pickedImageFile = File(picked.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not pick image: $e'),
          backgroundColor: GamerTheme.redAccent,
        ),
      );
    }
  }

  void _selectAvatarPreset(String url) {
    setState(() {
      _pickedImageFile = null;
      _photoUrl = url;
    });
  }

  Future<void> _saveGamerId() async {
    if (!_formKey.currentState!.validate()) return;

    final rawUsername = _usernameController.text.toLowerCase().trim();
    if (_isUsernameAvailable == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose an available username'),
          backgroundColor: GamerTheme.redAccent,
        ),
      );
      return;
    }

    final uid = GamerAuthService().currentUid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication session expired. Please log in again.'),
          backgroundColor: GamerTheme.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String finalPhotoUrl = _photoUrl;
      if (_pickedImageFile != null) {
        finalPhotoUrl = await GamerAuthService().uploadProfilePhoto(_pickedImageFile!, uid);
      }

      final gamerUser = GamerUser(
        uid: uid,
        username: rawUsername,
        displayName: _displayNameController.text.trim().isNotEmpty
            ? _displayNameController.text.trim()
            : rawUsername,
        photoUrl: finalPhotoUrl,
        coverUrl: widget.existingUser?.coverUrl ?? '',
        bio: _bioController.text.trim(),
        favoriteGame: _selectedGame,
        rank: _rankController.text.trim().isNotEmpty ? _rankController.text.trim() : 'Pro Gamer',
        followersCount: widget.existingUser?.followersCount ?? 0,
        followingCount: widget.existingUser?.followingCount ?? 0,
        postsCount: widget.existingUser?.postsCount ?? 0,
        createdAt: widget.existingUser?.createdAt ?? DateTime.now(),
      );

      await GamerAuthService().saveGamerProfile(gamerUser);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditing ? 'Gamer ID updated!' : 'Welcome to Gamers ID, @$rawUsername! 🎮'),
          backgroundColor: GamerTheme.neonGreen,
        ),
      );

      if (widget.isEditing) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const GamerMainNavigationScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save Gamer ID: $e'),
          backgroundColor: GamerTheme.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.isEditing;

    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Gamer ID' : 'Create Your Gamer ID'),
        automaticallyImplyLeading: isEditing,
        actions: [
          if (isEditing)
            TextButton(
              onPressed: _isSaving ? null : _saveGamerId,
              child: const Text('Save', style: TextStyle(color: GamerTheme.accentBlue, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Badge
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: GamerTheme.blueOrangeGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.sports_esports_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'OFFICIAL GAMER PASS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isEditing ? 'Customize Your Identity' : 'Claim Your Unique Handle',
                        style: const TextStyle(
                          color: GamerTheme.textWhite,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your Gamer ID is your public profile across all games.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: GamerTheme.textGray.withOpacity(0.9), fontSize: 13),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Profile Photo Section
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          _pickedImageFile != null
                              ? Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: GamerTheme.accentBlue, width: 2.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: GamerTheme.accentBlue.withOpacity(0.4),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Image.file(_pickedImageFile!, width: 100, height: 100, fit: BoxFit.cover),
                                  ),
                                )
                              : GamerAvatar(
                                  photoUrl: _photoUrl,
                                  displayName: _displayNameController.text.isNotEmpty
                                      ? _displayNameController.text
                                      : 'G',
                                  radius: 50,
                                  hasGlow: true,
                                  borderColor: GamerTheme.accentOrange,
                                ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: _pickImageFromGallery,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  gradient: GamerTheme.flameOrangeGradient,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _pickImageFromGallery,
                        icon: const Icon(Icons.photo_library_rounded, size: 16, color: GamerTheme.accentBlue),
                        label: const Text(
                          'Upload Photo From Gallery',
                          style: TextStyle(color: GamerTheme.accentBlue, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),

                      // Avatar Presets Quick Select
                      const SizedBox(height: 6),
                      Text(
                        'Or pick a quick avatar preset:',
                        style: TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _avatarPresets.map((preset) {
                          final isSelected = _photoUrl == preset && _pickedImageFile == null;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: () => _selectAvatarPreset(preset),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? GamerTheme.accentOrange : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                                child: GamerAvatar(
                                  photoUrl: preset,
                                  displayName: 'P',
                                  radius: 18,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // 1. Username Field (Crucial!)
                const Text(
                  'USERNAME (Unique Gamer Handle)',
                  style: TextStyle(color: GamerTheme.accentBlue, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _usernameController,
                  onChanged: _onUsernameChanged,
                  style: const TextStyle(color: GamerTheme.textWhite, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.alternate_email_rounded, color: GamerTheme.accentBlue),
                    hintText: 'e.g. shadow_hunter, bgmi_king',
                    suffixIcon: _isCheckingUsername
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: GamerTheme.accentBlue),
                            ),
                          )
                        : _isUsernameAvailable == true
                            ? const Icon(Icons.check_circle_rounded, color: GamerTheme.neonGreen)
                            : _isUsernameAvailable == false
                                ? const Icon(Icons.cancel_rounded, color: GamerTheme.redAccent)
                                : null,
                  ),
                  validator: (val) {
                    final clean = (val ?? '').toLowerCase().trim();
                    if (clean.isEmpty) return 'Username is required';
                    if (clean.length < 3) return 'Minimum 3 characters';
                    if (clean.length > 15) return 'Maximum 15 characters';
                    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(clean)) {
                      return 'Only lowercase letters, numbers, and underscore allowed';
                    }
                    if (_isUsernameAvailable == false) {
                      return 'Username already taken';
                    }
                    return null;
                  },
                ),
                if (_usernameFeedback.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        _isUsernameAvailable == true
                            ? Icons.check
                            : _isUsernameAvailable == false
                                ? Icons.close
                                : Icons.info_outline,
                        size: 14,
                        color: _isUsernameAvailable == true
                            ? GamerTheme.neonGreen
                            : _isUsernameAvailable == false
                                ? GamerTheme.redAccent
                                : GamerTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _usernameFeedback,
                          style: TextStyle(
                            color: _isUsernameAvailable == true
                                ? GamerTheme.neonGreen
                                : _isUsernameAvailable == false
                                    ? GamerTheme.redAccent
                                    : GamerTheme.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),

                // 2. Display Name Field
                const Text(
                  'DISPLAY NAME (In-Game Name)',
                  style: TextStyle(color: GamerTheme.textGray, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _displayNameController,
                  style: const TextStyle(color: GamerTheme.textWhite),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_rounded, color: GamerTheme.textMuted),
                    hintText: 'e.g. Fauji Gamer, Toxic Soul',
                  ),
                  validator: (val) {
                    if ((val ?? '').trim().isEmpty) return 'Display Name is required';
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // 3. Favorite Game Dropdown
                const Text(
                  'FAVORITE GAME',
                  style: TextStyle(color: GamerTheme.textGray, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: GamerTheme.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: GamerTheme.borderDark),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedGame,
                      isExpanded: true,
                      dropdownColor: GamerTheme.cardElevated,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: GamerTheme.accentBlue),
                      items: GamerTheme.favoriteGames.map((game) {
                        final emoji = GamerTheme.gameEmojis[game] ?? '🎮';
                        final color = GamerTheme.gameColors[game] ?? GamerTheme.accentBlue;
                        return DropdownMenuItem<String>(
                          value: game,
                          child: Row(
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 10),
                              Text(
                                game,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedGame = val);
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 4. Rank / Level Field
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'RANK / TIER',
                      style: TextStyle(color: GamerTheme.textGray, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                    ),
                    Text(
                      'e.g. Ace, Heroic, Radiant',
                      style: TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _rankController,
                  style: const TextStyle(color: GamerTheme.textWhite),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.military_tech_rounded, color: GamerTheme.accentOrange),
                    hintText: 'e.g. Ace Master, Heroic Tier',
                  ),
                  validator: (val) {
                    if ((val ?? '').trim().isEmpty) return 'Rank/Level is required';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _rankSuggestions.map((rank) {
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _rankController.text = rank;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: GamerTheme.cardElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: GamerTheme.borderLight),
                        ),
                        child: Text(
                          rank,
                          style: const TextStyle(color: GamerTheme.accentOrange, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // 5. Bio Field (Max 100 chars)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'GAMER BIO',
                      style: TextStyle(color: GamerTheme.textGray, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _bioController,
                      builder: (context, value, _) {
                        final count = value.text.length;
                        return Text(
                          '$count/100',
                          style: TextStyle(
                            color: count > 100 ? GamerTheme.redAccent : GamerTheme.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bioController,
                  maxLength: 100,
                  maxLines: 2,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => const SizedBox.shrink(),
                  style: const TextStyle(color: GamerTheme.textWhite),
                  decoration: const InputDecoration(
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: Icon(Icons.edit_note_rounded, color: GamerTheme.textMuted),
                    ),
                    hintText: 'e.g. BGMI Conqueror | Free Fire Lover | Clan Leader',
                  ),
                ),

                const SizedBox(height: 32),

                // Save / Complete Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveGamerId,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: GamerTheme.blueOrangeGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isEditing ? Icons.check_rounded : Icons.sports_esports_rounded,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isEditing ? 'Save Changes' : 'Create Gamer ID & Join',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
