import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/gamer_theme.dart';
import '../constants/mobile_games_rank_data.dart';
import '../models/gamer_user_model.dart';
import '../services/gamer_auth_service.dart';
import '../widgets/gamer_avatar.dart';
import 'coin_store_screen.dart';
import 'gamer_main_navigation_screen.dart';
import 'gamer_profile_screen.dart';

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
  String _selectedRankGame = 'BGMI (Battlegrounds Mobile India)';
  String _photoUrl = '';
  String _coverUrl = '';
  File? _pickedImageFile;
  File? _pickedCoverFile;
  File? _pickedRankScreenshot;
  String _rankScreenshotUrl = '';
  String _rankStatus = 'None';
  String _rankRejectReason = '';
  bool _isSaving = false;

  // Store perks: Profile Frame & Badge
  String _selectedFrame = '';
  List<String> _unlockedFrames = [];
  String _selectedBadge = '';
  List<String> _unlockedBadges = [];

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

  // Dynamic Ranks strictly per selected mobile game
  List<String> get _dynamicRanks {
    return MobileGamesRankData.getRanksForGame(_selectedRankGame);
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
      _selectedRankGame = MobileGamesRankData.resolveGameName(
        u.selectedGame.isNotEmpty ? u.selectedGame : u.favoriteGame,
      );
      final rawUserRank = u.selectedRank.isNotEmpty ? u.selectedRank : u.rank;
      _rankController.text = (rawUserRank.isNotEmpty && rawUserRank != 'None' && rawUserRank != 'Skip') ? rawUserRank : '';
      _gameIdController.text = u.gameId.isNotEmpty ? u.gameId : '12345';
      _photoUrl = u.photoUrl;
      _coverUrl = u.coverUrl;
      _rankScreenshotUrl = u.rankScreenshot;
      _rankStatus = u.rankStatus;
      _rankRejectReason = u.rankRejectReason;
      _isUsernameAvailable = true;
      _selectedFrame = u.activeFrame;
      _unlockedFrames = List<String>.from(u.unlockedFrames);
      _selectedBadge = u.activeBadge;
      _unlockedBadges = List<String>.from(u.unlockedBadges);
    } else {
      final fbUser = GamerAuthService().currentUser;
      if (fbUser != null) {
        _displayNameController.text = fbUser.displayName ?? '';
        if (fbUser.photoURL != null && fbUser.photoURL!.isNotEmpty) {
          _photoUrl = fbUser.photoURL!;
        }
      }
      _rankController.text = '';
      _gameIdController.text = '12345';
    }
    _loadStorePerks();
  }

  Future<void> _loadStorePerks() async {
    final uid = widget.existingUser?.uid ?? GamerAuthService().currentUid;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final localFrame = prefs.getString('user_active_frame_$uid') ?? '';
      final localFrames = prefs.getStringList('user_unlocked_frames_$uid') ?? [];
      final localBadge = prefs.getString('user_active_badge_$uid') ?? '';
      final localBadges = prefs.getStringList('user_unlocked_badges_$uid') ?? [];

      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() ?? {};
        final activeF = (data['activeFrame'] as String?) ?? localFrame;
        final unF = List<String>.from(data['unlockedFrames'] ?? localFrames);
        final activeB = (data['activeBadge'] as String?) ?? localBadge;
        final unB = List<String>.from(data['unlockedBadges'] ?? localBadges);

        setState(() {
          _selectedFrame = activeF;
          _unlockedFrames = unF;
          _selectedBadge = activeB;
          _unlockedBadges = unB;
        });
        return;
      }

      if (mounted) {
        setState(() {
          if (_selectedFrame.isEmpty) _selectedFrame = localFrame;
          if (_unlockedFrames.isEmpty) _unlockedFrames = localFrames;
          if (_selectedBadge.isEmpty) _selectedBadge = localBadge;
          if (_unlockedBadges.isEmpty) _unlockedBadges = localBadges;
        });
      }
    } catch (_) {}
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

  Future<void> _pickRankScreenshot(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (picked != null) {
        setState(() {
          _pickedRankScreenshot = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick screenshot: $e'),
            backgroundColor: GamerTheme.redAccent,
          ),
        );
      }
    }
  }

  void _showRankScreenshotPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10141D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload Rank Screenshot Proof',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'اسکرین شاٹ میں گیم کی اصل ID اور Rank صاف نظر آنا چاہیے',
                style: TextStyle(
                  color: Color(0xFF8B949E),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF00FF88)),
                title: const Text('Choose from Gallery / گیلری سے منتخب کریں', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickRankScreenshot(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF38BDF8)),
                title: const Text('Take Photo / کیمرہ سے تصویر لیں', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickRankScreenshot(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
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

      // Rank & Screenshot verification logic
      final enteredRank = _rankController.text.trim();
      String finalRank = '';
      String finalRankScreenshot = _rankScreenshotUrl;
      String finalRankStatus = _rankStatus;
      String finalRankVerifiedBy = widget.existingUser?.rankVerifiedBy ?? '';
      String finalRankRejectReason = widget.existingUser?.rankRejectReason ?? '';
      bool isRankVerified = widget.existingUser?.isRankVerified ?? false;

      if (enteredRank.isNotEmpty && enteredRank.toLowerCase() != 'none' && enteredRank.toLowerCase() != 'skip') {
        if (_pickedRankScreenshot != null) {
          // Upload new screenshot proof
          finalRankScreenshot = await GamerAuthService().uploadRankScreenshot(_pickedRankScreenshot!, uid);
          finalRank = enteredRank;
          finalRankStatus = 'Pending'; // Mark Pending for Admin
          finalRankRejectReason = '';
          isRankVerified = false;
        } else if (finalRankScreenshot.isNotEmpty) {
          finalRank = enteredRank;
          if (enteredRank != widget.existingUser?.rank) {
            finalRankStatus = 'Pending';
            isRankVerified = false;
          }
        } else {
          // User chose a rank but didn't upload a screenshot:
          // Rule 3: Rank is not saved and left Optional
          finalRank = '';
          finalRankStatus = 'None';
          finalRankScreenshot = '';
          isRankVerified = false;
        }
      } else {
        // Skipped
        finalRank = '';
        finalRankStatus = 'None';
        finalRankScreenshot = '';
        isRankVerified = false;
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
        selectedGame: finalRank.isNotEmpty ? _selectedRankGame : '',
        selectedRank: finalRank,
        rank: finalRank,
        rankScreenshot: finalRankScreenshot,
        rankStatus: finalRankStatus,
        rankVerifiedBy: finalRankVerifiedBy,
        rankRejectReason: finalRankRejectReason,
        isRankVerified: isRankVerified,
        followersCount: widget.existingUser?.followersCount ?? 0,
        followingCount: widget.existingUser?.followingCount ?? 0,
        postsCount: widget.existingUser?.postsCount ?? 0,
        likesReceived: widget.existingUser?.likesReceived ?? 0,
        reportsCount: widget.existingUser?.reportsCount ?? 0,
        isVerified: widget.existingUser?.isVerified ?? false,
        gameId: _gameIdController.text.trim().isNotEmpty ? _gameIdController.text.trim() : '12345',
        createdAt: widget.existingUser?.createdAt ?? DateTime.now(),
        activeFrame: _selectedFrame,
        unlockedFrames: _unlockedFrames,
        activeBadge: _selectedBadge,
        unlockedBadges: _unlockedBadges,
        chatColor: widget.existingUser?.chatColor ?? '#00FF66',
        unlockedChatColors: widget.existingUser?.unlockedChatColors ?? [],
        isVipMember: widget.existingUser?.isVipMember ?? false,
        vipTournamentPassUntil: widget.existingUser?.vipTournamentPassUntil,
        leaderboardSpotlightUntil: widget.existingUser?.leaderboardSpotlightUntil,
      );

      await GamerAuthService().saveGamerProfile(gamerUser);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_active_frame_$uid', _selectedFrame);
        await prefs.setStringList('user_unlocked_frames_$uid', _unlockedFrames);
        await prefs.setString('user_active_badge_$uid', _selectedBadge);
        await prefs.setStringList('user_unlocked_badges_$uid', _unlockedBadges);
      } catch (_) {}

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enteredRank.isNotEmpty && finalRank.isEmpty
                ? 'Profile updated. Note: Rank was skipped because screenshot proof was not uploaded.'
                : (widget.isEditing ? 'Gamer ID updated!' : 'Welcome to Gamers ID, @$rawUsername! 🎮'),
          ),
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
                                  child: GamerAvatar(
                                    photoUrl: _photoUrl,
                                    imageFile: _pickedImageFile,
                                    displayName: _displayNameController.text.isNotEmpty
                                        ? _displayNameController.text
                                        : 'F',
                                    radius: 48,
                                    hasGlow: true,
                                    borderColor: GamerTheme.accentOrange,
                                    frameId: _selectedFrame,
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

                      const SizedBox(height: 18),

                      // 4. AVATAR FRAMES & PRESTIGE BADGES (STORE PERKS)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: GamerTheme.cardDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: GamerTheme.borderDark),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'AVATAR FRAME',
                                      style: TextStyle(
                                        color: GamerTheme.textWhite,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const CoinStoreScreen()),
                                    );
                                    _loadStorePerks();
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: GamerTheme.neonGreen.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: GamerTheme.neonGreen.withOpacity(0.5)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.storefront_rounded, color: GamerTheme.neonGreen, size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          'COIN STORE',
                                          style: TextStyle(
                                            color: GamerTheme.neonGreen,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  {
                                    'id': '',
                                    'name': 'None',
                                    'emoji': '🚫',
                                    'color': Colors.white38,
                                  },
                                  {
                                    'id': 'neon_fire',
                                    'name': 'Neon Fire',
                                    'emoji': '🔥',
                                    'color': Colors.deepOrangeAccent,
                                  },
                                  {
                                    'id': 'royal_crown',
                                    'name': 'Royal Crown',
                                    'emoji': '👑',
                                    'color': Colors.amber,
                                  },
                                  {
                                    'id': 'cyber_glitch',
                                    'name': 'Cyber Grid',
                                    'emoji': '⚡',
                                    'color': GamerTheme.neonGreen,
                                  },
                                  {
                                    'id': 'cosmic_void',
                                    'name': 'Cosmic Nebula',
                                    'emoji': '🌌',
                                    'color': const Color(0xFFC084FC),
                                  },
                                ].map((f) {
                                  final id = f['id'] as String;
                                  final isNone = id.isEmpty;
                                  final isUnlocked = isNone || _unlockedFrames.contains(id);
                                  final isEquipped = _selectedFrame == id;
                                  final color = f['color'] as Color;

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: InkWell(
                                      onTap: () {
                                        if (isUnlocked) {
                                          setState(() => _selectedFrame = id);
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('${f['name']} is locked! Unlock it in the Coin Store.'),
                                              backgroundColor: GamerTheme.accentOrange,
                                              action: SnackBarAction(
                                                label: 'STORE',
                                                textColor: Colors.white,
                                                onPressed: () async {
                                                  await Navigator.of(context).push(
                                                    MaterialPageRoute(builder: (_) => const CoinStoreScreen()),
                                                  );
                                                  _loadStorePerks();
                                                },
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: isEquipped ? color.withOpacity(0.2) : GamerTheme.bgDark,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isEquipped
                                                ? color
                                                : (isUnlocked ? GamerTheme.borderLight : GamerTheme.borderDark),
                                            width: isEquipped ? 2 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(f['emoji'] as String, style: const TextStyle(fontSize: 14)),
                                            const SizedBox(width: 6),
                                            Text(
                                              f['name'] as String,
                                              style: TextStyle(
                                                color: isEquipped ? Colors.white : (isUnlocked ? Colors.white70 : GamerTheme.textMuted),
                                                fontSize: 11,
                                                fontWeight: isEquipped ? FontWeight.w900 : FontWeight.w600,
                                              ),
                                            ),
                                            if (!isUnlocked) ...[
                                              const SizedBox(width: 5),
                                              const Icon(Icons.lock_rounded, size: 12, color: Colors.amber),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Divider(color: GamerTheme.borderDark, height: 1),
                            const SizedBox(height: 12),
                            // BADGES ROW
                            const Row(
                              children: [
                                Icon(Icons.military_tech_rounded, color: GamerTheme.accentBlue, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'GAMER BADGE',
                                  style: TextStyle(
                                    color: GamerTheme.textWhite,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  {
                                    'id': '',
                                    'name': 'None',
                                  },
                                  {
                                    'id': 'pro_elite',
                                    'name': 'PRO ELITE',
                                  },
                                  {
                                    'id': 'kd_assassin',
                                    'name': 'ASSASSIN 💀',
                                  },
                                  {
                                    'id': 'room_champion',
                                    'name': 'CHAMPION 🏆',
                                  },
                                ].map((b) {
                                  final id = b['id'] as String;
                                  final isNone = id.isEmpty;
                                  final isUnlocked = isNone || _unlockedBadges.contains(id);
                                  final isEquipped = _selectedBadge == id;

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: InkWell(
                                      onTap: () {
                                        if (isUnlocked) {
                                          setState(() => _selectedBadge = id);
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('${b['name']} is locked! Unlock it in the Coin Store.'),
                                              backgroundColor: GamerTheme.accentBlue,
                                              action: SnackBarAction(
                                                label: 'STORE',
                                                textColor: Colors.white,
                                                onPressed: () async {
                                                  await Navigator.of(context).push(
                                                    MaterialPageRoute(builder: (_) => const CoinStoreScreen()),
                                                  );
                                                  _loadStorePerks();
                                                },
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isEquipped ? GamerTheme.accentBlue.withOpacity(0.2) : GamerTheme.bgDark,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isEquipped
                                                ? GamerTheme.accentBlue
                                                : (isUnlocked ? GamerTheme.borderLight : GamerTheme.borderDark),
                                            width: isEquipped ? 2 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isNone)
                                              const Text('None', style: TextStyle(color: Colors.white70, fontSize: 11))
                                            else
                                              GamerBadgeWidget(badgeId: id, scale: 0.9),
                                            if (!isUnlocked) ...[
                                              const SizedBox(width: 5),
                                              const Icon(Icons.lock_rounded, size: 12, color: Colors.amber),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
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
                                  final ranks = _dynamicRanks;
                                  if (_rankController.text.trim().isNotEmpty && !ranks.contains(_rankController.text.trim())) {
                                    _rankController.text = ranks.first;
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 4. MOBILE GAMES RANK / TIER & SCREENSHOT VERIFICATION
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.military_tech_rounded, color: Color(0xFFFF8A00), size: 18),
                              const SizedBox(width: 6),
                              const Text(
                                'MOBILE GAMES RANK / TIER',
                                style: TextStyle(
                                  color: GamerTheme.textGray,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: const BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.all(Radius.circular(6)),
                                ),
                                child: const Text(
                                  'Optional / اختیاری',
                                  style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          if (_rankController.text.trim().isNotEmpty)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _rankController.clear();
                                  _pickedRankScreenshot = null;
                                  _rankScreenshotUrl = '';
                                  _rankStatus = 'None';
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: GamerTheme.cardElevated,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: GamerTheme.borderLight),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.close_rounded, size: 12, color: GamerTheme.textMuted),
                                    SizedBox(width: 4),
                                    Text(
                                      'Skip / چھوڑ دیں',
                                      style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 1. GAME SELECTION DROPDOWN (15 Major Mobile Games)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        decoration: BoxDecoration(
                          color: GamerTheme.cardElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: GamerTheme.borderLight),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: MobileGamesRankData.games.contains(_selectedRankGame)
                                ? _selectedRankGame
                                : MobileGamesRankData.games.first,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF161B26),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF00FF88)),
                            items: MobileGamesRankData.games.map((game) {
                              final emoji = MobileGamesRankData.getGameEmoji(game);
                              final color = MobileGamesRankData.getGameColor(game);
                              return DropdownMenuItem<String>(
                                value: game,
                                child: Row(
                                  children: [
                                    Text(emoji, style: const TextStyle(fontSize: 18)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        game,
                                        style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedRankGame = val;
                                  _selectedGame = val;
                                  final ranks = _dynamicRanks;
                                  if (_rankController.text.trim().isNotEmpty && !ranks.contains(_rankController.text.trim())) {
                                    _rankController.clear();
                                    _pickedRankScreenshot = null;
                                    _rankScreenshotUrl = '';
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 2. RANK SELECTION (Top 10 Ranks for selected game)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'SELECT RANK / رینک منتخب کریں (Top 10)',
                            style: TextStyle(
                              color: GamerTheme.textGray,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            _selectedRankGame.length > 20 ? '${_selectedRankGame.substring(0, 20)}...' : _selectedRankGame,
                            style: TextStyle(
                              color: MobileGamesRankData.getGameColor(_selectedRankGame),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Top 10 Dynamic Rank Chips & Skip Option
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Skip / No Rank chip
                          InkWell(
                            onTap: () {
                              setState(() {
                                _rankController.clear();
                                _pickedRankScreenshot = null;
                                _rankScreenshotUrl = '';
                                _rankStatus = 'None';
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: _rankController.text.trim().isEmpty
                                    ? GamerTheme.accentBlue.withOpacity(0.2)
                                    : GamerTheme.cardElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _rankController.text.trim().isEmpty ? GamerTheme.accentBlue : GamerTheme.borderLight,
                                  width: _rankController.text.trim().isEmpty ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_rankController.text.trim().isEmpty) ...[
                                    const Icon(Icons.check, color: GamerTheme.accentBlue, size: 12),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    'Skip / No Rank (چھوڑ دیں)',
                                    style: TextStyle(
                                      color: _rankController.text.trim().isEmpty ? GamerTheme.accentBlue : Colors.white70,
                                      fontSize: 12,
                                      fontWeight: _rankController.text.trim().isEmpty ? FontWeight.w900 : FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Top 10 dynamic ranks for selected game
                          ..._dynamicRanks.map((rank) {
                            final isSelected = _rankController.text.trim() == rank;
                            final gameColor = MobileGamesRankData.getGameColor(_selectedRankGame);
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _rankController.text = rank;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected ? gameColor.withOpacity(0.2) : GamerTheme.cardElevated,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? gameColor : GamerTheme.borderLight,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSelected) ...[
                                      Icon(Icons.check, color: gameColor, size: 12),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      rank,
                                      style: TextStyle(
                                        color: isSelected ? gameColor : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),

                      // SCREENSHOT PROOF UPLOAD (Mandatory when Rank is selected)
                      if (_rankController.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10141D),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: (_pickedRankScreenshot != null || _rankScreenshotUrl.isNotEmpty)
                                  ? const Color(0xFF00FF88).withOpacity(0.4)
                                  : const Color(0xFFFF8A00).withOpacity(0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Status Banner if previously reviewed or pending
                              if (_rankStatus.toLowerCase() == 'pending') ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF332B00),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFFFD700)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.hourglass_top_rounded, color: Color(0xFFFFD700), size: 16),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Rank Verification Pending ⏳ (تصدیق کے لیے زیر التواء)',
                                          style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 11.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ] else if (_rankStatus.toLowerCase() == 'verified') ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D2818),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF00FF88)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.verified_rounded, color: Color(0xFF00FF88), size: 16),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Verified ✓ (آپ کا رینک تصدیق شدہ ہے)',
                                          style: TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 11.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ] else if (_rankStatus.toLowerCase() == 'rejected') ...[
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3A0D11),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFFF4655)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.error_outline_rounded, color: Color(0xFFFF4655), size: 16),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'آپ کا اسکرین شاٹ درست نہیں ہے، دوبارہ اپلوڈ کریں',
                                              style: TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_rankRejectReason.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'وجہ: $_rankRejectReason',
                                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],

                              // Instructions notice
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161B26),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF2E384D)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 16),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'اسکرین شاٹ میں گیم کی اصل ID اور Rank صاف نظر آنا چاہیے',
                                        style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Image Preview or Upload Prompt
                              if (_pickedRankScreenshot != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Stack(
                                    children: [
                                      Image.file(
                                        _pickedRankScreenshot!,
                                        height: 140,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: CircleAvatar(
                                          radius: 14,
                                          backgroundColor: Colors.black.withOpacity(0.7),
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.close, size: 14, color: Colors.white),
                                            onPressed: () => setState(() => _pickedRankScreenshot = null),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _showRankScreenshotPickerSheet,
                                        icon: const Icon(Icons.edit_rounded, size: 14, color: Color(0xFF00FF88)),
                                        label: const Text('تصویر تبدیل کریں (Change Screenshot)', style: TextStyle(color: Color(0xFF00FF88), fontSize: 11.5)),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Color(0xFF00FF88)),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if (_rankScreenshotUrl.isNotEmpty) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CachedNetworkImage(
                                    imageUrl: _rankScreenshotUrl,
                                    height: 140,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      height: 140,
                                      color: const Color(0xFF161B26),
                                      child: const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88), strokeWidth: 2)),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      height: 140,
                                      color: const Color(0xFF161B26),
                                      child: const Center(child: Icon(Icons.broken_image, color: Colors.white38)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _showRankScreenshotPickerSheet,
                                        icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF00FF88)),
                                        label: const Text('نیا اسکرین شاٹ اپلوڈ کریں (Replace)', style: TextStyle(color: Color(0xFF00FF88), fontSize: 11.5)),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Color(0xFF00FF88)),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                InkWell(
                                  onTap: _showRankScreenshotPickerSheet,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF161B26),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFFF8A00).withOpacity(0.6),
                                        style: BorderStyle.solid,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Column(
                                      children: [
                                        Icon(Icons.add_photo_alternate_rounded, color: Color(0xFFFF8A00), size: 36),
                                        SizedBox(height: 8),
                                        Text(
                                          'اسکرین شاٹ اپلوڈ کریں (Upload Screenshot)',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'رینک محفوظ کرنے کے لیے اسکرین شاٹ لازمی ہے',
                                          style: TextStyle(
                                            color: Color(0xFFFF8A00),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

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

                      // NEW SECTION: "My Game Ranks"
                      if (widget.existingUser != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: GamerTheme.cardDark,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.shield_rounded, color: Color(0xFF00E5FF), size: 18),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'MY GAME RANKS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const Spacer(),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (sheetContext) => AddVerifyGameRankSheet(user: widget.existingUser!),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF00E5FF)),
                                      backgroundColor: const Color(0xFF00E5FF).withOpacity(0.1),
                                      foregroundColor: const Color(0xFF00E5FF),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.add_moderator_rounded, size: 14),
                                    label: const Text('Add / Verify Game Rank', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (widget.existingUser!.games.isEmpty)
                                const Text(
                                  'No game ranks submitted yet. Tap "Add / Verify Game Rank" to submit screenshot proof for BGMI, Free Fire, Valorant & more.',
                                  style: TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: widget.existingUser!.games.map((g) {
                                    final isApproved = g.isVerified || g.status == 'approved';
                                    final isPending = g.status == 'pending';
                                    final color = isApproved
                                        ? const Color(0xFF00FF88)
                                        : (isPending ? const Color(0xFFFF8A00) : const Color(0xFFFF4655));
                                    return Chip(
                                      backgroundColor: color.withOpacity(0.12),
                                      side: BorderSide(color: color.withOpacity(0.5)),
                                      label: Text(
                                        '${g.gameName}: ${g.verifiedRank.isNotEmpty ? g.verifiedRank : g.claimedRank} (${g.status})',
                                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                      ],

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
