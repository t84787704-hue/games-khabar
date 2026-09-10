import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  final _gameIdController = TextEditingController();

  String _selectedGame = 'BGMI';
  String _photoUrl = '';
  String _coverUrl = '';
  File? _pickedImageFile;
  File? _pickedCoverFile;
  bool _isSaving = false;

  // Live username availability check state
  Timer? _debounceTimer;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String _usernameFeedback = '';

  // BGMI Theme default cover image
  static const String _defaultBgmiCoverUrl =
      'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=1200&auto=format&fit=crop&q=80';

  // Gaming avatar presets (Helmet, Skull, Ninja, Crown, Crosshair)
  final List<Map<String, dynamic>> _gamingPresets = [
    {
      'id': 'preset:helmet',
      'label': 'Helmet',
      'icon': Icons.sports_motorsports_rounded,
      'color': const Color(0xFF60A5FA),
      'bg': const [Color(0xFF1E293B), Color(0xFF0F172A)],
    },
    {
      'id': 'preset:skull',
      'label': 'Skull',
      'icon': Icons.dangerous_rounded,
      'color': const Color(0xFFFF5252),
      'bg': const [Color(0xFF3B0764), Color(0xFF180322)],
    },
    {
      'id': 'preset:ninja',
      'label': 'Ninja',
      'icon': Icons.masks_rounded,
      'color': const Color(0xFFC084FC),
      'bg': const [Color(0xFF1E1B4B), Color(0xFF0F0E2A)],
    },
    {
      'id': 'preset:crown',
      'label': 'Crown',
      'icon': Icons.workspace_premium_rounded,
      'color': const Color(0xFFFFD700),
      'bg': const [Color(0xFF312E81), Color(0xFF18181B)],
    },
    {
      'id': 'preset:crosshair',
      'label': 'Crosshair',
      'icon': Icons.filter_center_focus_rounded,
      'color': const Color(0xFF00E676),
      'bg': const [Color(0xFF064E3B), Color(0xFF022C22)],
    },
  ];

  // Dynamic Ranks strictly per selected game
  List<String> get _dynamicRanks {
    switch (_selectedGame) {
      case 'BGMI':
      case 'PUBG Mobile':
        return const ['Ace', 'Conqueror', 'Ace Master', 'Ace Dominator'];
      case 'Free Fire':
      case 'Free Fire Max':
        return const ['Heroic', 'Grandmaster'];
      case 'Valorant':
        return const ['Radiant', 'Immortal', 'Diamond'];
      case 'Call of Duty Mobile':
      case 'COD Mobile':
        return const ['Legendary', 'Master', 'Grandmaster'];
      default:
        return const ['Ace', 'Conqueror', 'Ace Master', 'Ace Dominator'];
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.existingUser != null) {
      final u = widget.existingUser!;
      _usernameController.text = u.username;
      _displayNameController.text = u.displayName;
      _bioController.text = u.bio;
      _selectedGame = GamerTheme.favoriteGames.contains(u.favoriteGame) ? u.favoriteGame : 'BGMI';
      _rankController.text = u.rank.isNotEmpty ? u.rank : _dynamicRanks.first;
      _gameIdController.text = u.gameId.isNotEmpty ? u.gameId : '12345';
      _photoUrl = u.photoUrl;
      _coverUrl = u.coverUrl;
      _isUsernameAvailable = true;
    } else {
      final fbUser = GamerAuthService().currentUser;
      if (fbUser != null) {
        _displayNameController.text = fbUser.displayName ?? '';
        if (fbUser.photoURL != null && fbUser.photoURL!.isNotEmpty) {
          _photoUrl = fbUser.photoURL!;
        }
      }
      _rankController.text = _dynamicRanks.first;
      _gameIdController.text = '12345';
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    _rankController.dispose();
    _gameIdController.dispose();
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

  Future<void> _pickCoverFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (picked != null) {
        setState(() {
          _pickedCoverFile = File(picked.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not pick cover image: $e'),
          backgroundColor: GamerTheme.redAccent,
        ),
      );
    }
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

      String finalCoverUrl = _coverUrl;
      if (_pickedCoverFile != null) {
        finalCoverUrl = await GamerAuthService().uploadCoverPhoto(_pickedCoverFile!, uid);
      }

      final gamerUser = GamerUser(
        uid: uid,
        username: rawUsername,
        displayName: _displayNameController.text.trim().isNotEmpty
            ? _displayNameController.text.trim()
            : rawUsername,
        photoUrl: finalPhotoUrl,
        coverUrl: finalCoverUrl.isNotEmpty ? finalCoverUrl : (widget.existingUser?.coverUrl ?? ''),
        bio: _bioController.text.trim(),
        favoriteGame: _selectedGame,
        rank: _rankController.text.trim().isNotEmpty ? _rankController.text.trim() : _dynamicRanks.first,
        followersCount: widget.existingUser?.followersCount ?? 0,
        followingCount: widget.existingUser?.followingCount ?? 0,
        postsCount: widget.existingUser?.postsCount ?? 0,
        likesReceived: widget.existingUser?.likesReceived ?? 0,
        reportsCount: widget.existingUser?.reportsCount ?? 0,
        isVerified: widget.existingUser?.isVerified ?? false,
        gameId: _gameIdController.text.trim().isNotEmpty ? _gameIdController.text.trim() : '12345',
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
              child: const Text('Save', style: TextStyle(color: GamerTheme.accentOrange, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TOP: Cover Photo Banner (BGMI theme + OFFICIAL GAMER PASS badge + Change Cover Photo button like Facebook)
                Stack(
                  children: [
                    Container(
                      height: 175,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_pickedCoverFile != null)
                            Image.file(_pickedCoverFile!, fit: BoxFit.cover)
                          else if (_coverUrl.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: _coverUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: const Color(0xFF0F172A)),
                              errorWidget: (_, __, ___) => Image.network(_defaultBgmiCoverUrl, fit: BoxFit.cover),
                            )
                          else
                            Image.network(
                              _defaultBgmiCoverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                            ),
                          // Dark Vignette & Gradient Overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.5),
                                  Colors.black.withOpacity(0.2),
                                  GamerTheme.bgDark.withOpacity(0.85),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          // Subtle BGMI Theme indicator
                          Positioned(
                            right: 14,
                            top: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: GamerTheme.accentOrange.withOpacity(0.5)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sports_esports_rounded, color: GamerTheme.accentOrange, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'BGMI THEME',
                                    style: TextStyle(
                                      color: GamerTheme.accentOrange,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 9.5,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Left Side: OFFICIAL GAMER PASS Badge
                    Positioned(
                      left: 16,
                      top: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: GamerTheme.blueOrangeGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sports_esports_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'OFFICIAL GAMER PASS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 10.5,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Right Side: Change Cover Photo Button (camera icon) like Facebook
                    Positioned(
                      right: 14,
                      bottom: 12,
                      child: InkWell(
                        onTap: _pickCoverFromGallery,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white38, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 5),
                              Text(
                                'Change Cover Photo',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Form content with horizontal padding
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. AVATAR: Keep F with orange glow and small camera icon, Upload Photo From Gallery text below
                      Center(
                        child: Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: GamerTheme.accentOrange.withOpacity(0.45),
                                        blurRadius: 18,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: _pickedImageFile != null
                                      ? Container(
                                          width: 96,
                                          height: 96,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: GamerTheme.accentOrange, width: 3),
                                          ),
                                          child: ClipOval(
                                            child: Image.file(_pickedImageFile!, width: 96, height: 96, fit: BoxFit.cover),
                                          ),
                                        )
                                      : GamerAvatar(
                                          photoUrl: _photoUrl,
                                          displayName: _displayNameController.text.isNotEmpty
                                              ? _displayNameController.text
                                              : 'F',
                                          radius: 48,
                                          hasGlow: true,
                                          borderColor: GamerTheme.accentOrange,
                                        ),
                                ),
                                // Small camera icon on bottom-right of avatar
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: InkWell(
                                    onTap: _pickImageFromGallery,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: const BoxDecoration(
                                        gradient: GamerTheme.flameOrangeGradient,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(color: Colors.black54, blurRadius: 4),
                                        ],
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _pickImageFromGallery,
                              icon: const Icon(Icons.photo_library_rounded, size: 16, color: GamerTheme.accentOrange),
                              label: const Text(
                                'Upload Photo From Gallery',
                                style: TextStyle(
                                  color: GamerTheme.accentOrange,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            // 3. CHANGE AVATAR PRESETS: Replace human faces with gaming icons like helmet, skull, ninja, crown, crosshair
                            const SizedBox(height: 10),
                            const Text(
                              'PRO GAMER AVATAR PRESETS',
                              style: TextStyle(
                                color: GamerTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _gamingPresets.map((preset) {
                                final isSelected = _photoUrl == preset['id'] && _pickedImageFile == null;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 5),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _pickedImageFile = null;
                                        _photoUrl = preset['id'] as String;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(24),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 46,
                                          height: 46,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: preset['bg'] as List<Color>,
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            border: Border.all(
                                              color: isSelected ? GamerTheme.accentOrange : Colors.white24,
                                              width: isSelected ? 2.5 : 1,
                                            ),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: GamerTheme.accentOrange.withOpacity(0.5),
                                                      blurRadius: 8,
                                                      spreadRadius: 1,
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: Center(
                                            child: Icon(
                                              preset['icon'] as IconData,
                                              color: preset['color'] as Color,
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          preset['label'] as String,
                                          style: TextStyle(
                                            color: isSelected ? GamerTheme.accentOrange : Colors.white70,
                                            fontSize: 10,
                                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 5. KEEP: Username @fua with Verified green tick
                      Row(
                        children: [
                          const Text(
                            'USERNAME (Unique Gamer Handle)',
                            style: TextStyle(color: GamerTheme.accentOrange, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, color: Color(0xFF00E676), size: 16),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _usernameController,
                        onChanged: _onUsernameChanged,
                        style: const TextStyle(color: GamerTheme.textWhite, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.alternate_email_rounded, color: GamerTheme.accentOrange),
                          hintText: 'fua',
                          suffixIcon: _isCheckingUsername
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: GamerTheme.accentOrange),
                                  ),
                                )
                              : const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 22),
                        ),
                        validator: (val) {
                          final clean = (val ?? '').toLowerCase().trim();
                          if (clean.isEmpty) return 'Username is required';
                          if (clean.length < 3) return 'Must be at least 3 characters';
                          if (clean.length > 15) return 'Maximum 15 characters';
                          if (!RegExp(r'^[a-z0-9_]+$').hasMatch(clean)) {
                            return 'Only lowercase letters, numbers, and _ are allowed';
                          }
                          return null;
                        },
                      ),
                      if (_usernameFeedback.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
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
                      ],

                      const SizedBox(height: 20),

                      // 5. KEEP: Display Name
                      const Text(
                        'DISPLAY NAME',
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

                      // 5. KEEP: Favorite Game dropdown (Dynamic Ranks trigger)
                      const Text(
                        'FAVORITE GAME',
                        style: TextStyle(color: GamerTheme.textGray, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: GamerTheme.cardElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: GamerTheme.borderLight),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: GamerTheme.favoriteGames.contains(_selectedGame) ? _selectedGame : GamerTheme.favoriteGames.first,
                            isExpanded: true,
                            dropdownColor: GamerTheme.cardElevated,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: GamerTheme.accentOrange),
                            items: GamerTheme.favoriteGames.map((game) {
                              final emoji = GamerTheme.gameEmojis[game] ?? '🎮';
                              final color = GamerTheme.gameColors[game] ?? GamerTheme.accentOrange;
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
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedGame = val;
                                  // Update to dynamic ranks for selected game
                                  final ranks = _dynamicRanks;
                                  if (!ranks.contains(_rankController.text.trim())) {
                                    _rankController.text = ranks.first;
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 4. DYNAMIC RANK SYSTEM:
                      // When FAVORITE GAME = BGMI, show ranks: Ace, Conqueror, Ace Master, Ace Dominator.
                      // When = Free Fire, show Heroic, Grandmaster.
                      // When = Valorant, show Radiant, Immortal, Diamond.
                      // Don't show all ranks mixed.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$_selectedGame RANK / TIER',
                            style: const TextStyle(
                              color: GamerTheme.textGray,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            'Dynamic for $_selectedGame',
                            style: const TextStyle(color: GamerTheme.accentOrange, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _rankController,
                        style: const TextStyle(color: GamerTheme.textWhite),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.military_tech_rounded, color: GamerTheme.accentOrange),
                          hintText: 'Select or enter your $_selectedGame rank',
                        ),
                        validator: (val) {
                          if ((val ?? '').trim().isEmpty) return 'Rank/Level is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _dynamicRanks.map((rank) {
                          final isSelected = _rankController.text.trim() == rank;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _rankController.text = rank;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? GamerTheme.accentOrange.withOpacity(0.2) : GamerTheme.cardElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? GamerTheme.accentOrange : GamerTheme.borderLight,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected) ...[
                                    const Icon(Icons.check, color: GamerTheme.accentOrange, size: 12),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    rank,
                                    style: TextStyle(
                                      color: isSelected ? GamerTheme.accentOrange : Colors.white70,
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),

                      // 5. KEEP: Gamer Bio
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
                          hintText: 'e.g. BGMI Conqueror | Clan Leader | Sniper Specialist',
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 5. KEEP: In-Game UID 12345 field. Remove BLUE TICK REQUIREMENT text, instead show small lock icon.
                      Row(
                        children: const [
                          Text(
                            'IN-GAME CHARACTER ID / UID',
                            style: TextStyle(color: GamerTheme.textGray, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.lock_rounded, size: 14, color: GamerTheme.textMuted),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _gameIdController,
                        style: const TextStyle(color: GamerTheme.textWhite),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.sports_esports_rounded, color: GamerTheme.accentOrange),
                          hintText: '12345',
                          helperText: 'Enter your official in-game character UID',
                          helperStyle: TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 6. BUTTON: Save Changes gradient orange
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
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF8A00), Color(0xFFFF5200)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF8A00).withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
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
                                        const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          isEditing ? 'Save Changes' : 'Save Changes & Join',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
