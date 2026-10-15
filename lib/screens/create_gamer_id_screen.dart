// ═══════════════════════════════════════════════════════════════════════════════
// EXACT DIFF:
// - Replaced .eq('id', uid) with .or('id.eq.$uid,uid.eq.$uid') on users table
// ═══════════════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/gamer_theme.dart';
import '../constants/mobile_games_rank_data.dart';
import '../models/gamer_user_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/supabase_service.dart';
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
  Timer? _lockedItemBannerTimer;

  void _showLockedItemBanner(String itemName) {
    _lockedItemBannerTimer?.cancel();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$itemName is locked! Unlock it in the Coin Store.'),
        backgroundColor: const Color(0xFF1877F2),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'STORE',
          textColor: Colors.white,
          onPressed: () async {
            _lockedItemBannerTimer?.cancel();
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CoinStoreScreen()),
            );
            _loadStorePerks();
          },
        ),
      ),
    );
    _lockedItemBannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    });
  }

  // ✅ NEW: Show "Coming Soon" banner for rank verification
  void _showRankComingSoonBanner() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Text('🚀', style: TextStyle(fontSize: 16)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Advanced rank verification coming soon! Abhi ke liye skip karein.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFF1877F2),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

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
        final meta = fbUser.userMetadata ?? {};
        final fullName = (meta['full_name'] ?? meta['name'] ?? meta['display_name'] ?? '').toString();
        final avatar = (meta['avatar_url'] ?? meta['picture'] ?? '').toString();
        _displayNameController.text = fullName;
        if (avatar.isNotEmpty) {
          _photoUrl = avatar;
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
      final localBadges = prefs.getStringList('user_unlocked_badges_$uid') ?? <String>[];
      final data = await SupabaseService.getUser(uid);
      if (data != null && mounted) {
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
    _lockedItemBannerTimer?.cancel();
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
      bool available = true;
      try {
        available = await GamerAuthService().isUsernameAvailable(
          clean,
          currentUid: widget.existingUser?.uid ?? GamerAuthService().currentUid,
        ).timeout(const Duration(seconds: 2), onTimeout: () => true);
      } catch (_) {
        available = true;
      }

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

    bool saveSucceeded = false;
    setState(() => _isSaving = true);

    try {
      // ✅ FIX 1: Profile photo upload — fail hone pe rok do
      String finalPhotoUrl = _photoUrl;
      if (_pickedImageFile != null) {
        final uploaded = await GamerAuthService().uploadProfilePhoto(_pickedImageFile!, uid);
        if (uploaded.isNotEmpty) {
          finalPhotoUrl = uploaded;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Profile photo upload fail! Try again.'),
                backgroundColor: GamerTheme.redAccent,
              ),
            );
          }
          setState(() => _isSaving = false);
          return;
        }
      }

      // ✅ FIX 2: Cover photo upload — fail hone pe rok do
      String finalCoverUrl = _coverUrl;
      if (_pickedCoverFile != null) {
        final uploaded = await GamerAuthService().uploadCoverPhoto(_pickedCoverFile!, uid);
        if (uploaded.isNotEmpty) {
          finalCoverUrl = uploaded;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Cover photo upload fail! Try again.'),
                backgroundColor: GamerTheme.redAccent,
              ),
            );
          }
          setState(() => _isSaving = false);
          return;
        }
      }

      // Rank & Screenshot verification logic (Optional)
      final enteredRank = _rankController.text.trim();
      String finalRank = '';
      String finalRankScreenshot = _rankScreenshotUrl;
      String finalRankStatus = 'none';
      String finalRankVerifiedBy = widget.existingUser?.rankVerifiedBy ?? '';
      String finalRankRejectReason = widget.existingUser?.rankRejectReason ?? '';
      bool isRankVerified = widget.existingUser?.isRankVerified ?? false;

      if (enteredRank.isNotEmpty && enteredRank.toLowerCase() != 'none' && enteredRank.toLowerCase() != 'skip') {
        finalRank = enteredRank;
        if (_pickedRankScreenshot != null) {
          // Upload new screenshot proof
          finalRankScreenshot = await GamerAuthService().uploadRankScreenshot(_pickedRankScreenshot!, uid);
          finalRankStatus = 'pending'; // Mark pending for Admin review
          finalRankRejectReason = '';
          isRankVerified = false;
        } else if (finalRankScreenshot.isNotEmpty) {
          finalRankStatus = widget.existingUser?.rankStatus.isNotEmpty == true
              ? widget.existingUser!.rankStatus
              : 'pending';
        } else {
          // User chose rank but skipped screenshot (Optional)
          finalRankStatus = 'none';
          finalRankScreenshot = '';
          isRankVerified = false;
        }
      } else {
        // Skipped
        finalRank = '';
        finalRankStatus = 'none';
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

      // Direct update in Supabase users table so avatar_url and cover_url are 100% saved
      final Map<String, dynamic> directUpdates = {
        'avatar_url': finalPhotoUrl,
        'cover_url': finalCoverUrl,
        'display_name': _displayNameController.text.trim().isNotEmpty
            ? _displayNameController.text.trim()
            : rawUsername,
        'bio': _bioController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      try {
        await SupabaseService.client
            .from('users')
            .update(directUpdates)
            .or('id.eq.$uid,uid.eq.$uid');
      } catch (_) {}

      // Evict old and new image caches so the profile screen updates immediately
      try {
        if (_photoUrl.isNotEmpty) await CachedNetworkImage.evictFromCache(_photoUrl);
        if (finalPhotoUrl.isNotEmpty) await CachedNetworkImage.evictFromCache(finalPhotoUrl);
        if (_coverUrl.isNotEmpty) await CachedNetworkImage.evictFromCache(_coverUrl);
        if (finalCoverUrl.isNotEmpty) await CachedNetworkImage.evictFromCache(finalCoverUrl);
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      } catch (_) {}

      try {
        await SupabaseService.client.from('users').update({
          'rank': finalRank.isNotEmpty ? finalRank : null,
          'selected_rank': finalRank.isNotEmpty ? finalRank : null,
          'is_rank_verified': isRankVerified,
          'rank_status': finalRankStatus,
          'rank_proof_url': finalRankScreenshot.isNotEmpty ? finalRankScreenshot : null,
        }).eq('id', uid);
      } catch (_) {}

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_active_frame_$uid', _selectedFrame);
        await prefs.setStringList('user_unlocked_frames_$uid', _unlockedFrames);
        await prefs.setString('user_active_badge_$uid', _selectedBadge);
        await prefs.setStringList('user_unlocked_badges_$uid', _unlockedBadges);
      } catch (_) {}

      // ✅ FIX: State variables update karo (naye URLs)
      if (finalPhotoUrl.isNotEmpty) {
        _photoUrl = finalPhotoUrl;
      }
      if (finalCoverUrl.isNotEmpty) {
        _coverUrl = finalCoverUrl;
      }

      // ✅ FIX: currentGamerNotifier update karo
      GamerAuthService().currentGamerNotifier.value = gamerUser;

      saveSucceeded = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save Gamer ID: $e'),
            backgroundColor: GamerTheme.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }

    if (saveSucceeded) {
      if (!mounted) return;

      // ✅ FIX: Picked files reset karo
      setState(() {
        _pickedImageFile = null;
        _pickedCoverFile = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditing ? 'Gamer ID updated!' : 'Welcome to Gamers ID, @$rawUsername! 🎮'),
          backgroundColor: GamerTheme.neonGreen,
        ),
      );

      if (widget.isEditing) {
        // ✅ FIX 3: Pop se pehle refreshCurrentGamer call karo
        try {
          await GamerAuthService().refreshCurrentGamer();
        } catch (_) {}
        Navigator.of(context).pop(true);
      } else {
        // Always navigate to main screen on save success
        // (don't wait for refreshCurrentGamer)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const GamerMainNavigationScreen()),
          (route) => false,
        );

        // Refresh profile in background
        GamerAuthService().refreshCurrentGamer();
      }
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
                        ],
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
                                          _showLockedItemBanner(f['name'] as String);
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
                                          _showLockedItemBanner(b['name'] as String);
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
                      // ✅ COMING SOON: Rank verification disabled — user can only Skip
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.military_tech_rounded, color: Color(0xFFFF8A00), size: 18),
                              const SizedBox(width: 6),
                              const Text(
                                'MY GAME RANK & PROOF',
                                style: TextStyle(
                                  color: GamerTheme.textGray,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          // ✅ NEW: Coming Soon badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1877F2), Color(0xFF00E5FF)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('🚀', style: TextStyle(fontSize: 10)),
                                SizedBox(width: 4),
                                Text(
                                  'COMING SOON',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // ✅ NEW: Coming soon message banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B26),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1877F2).withOpacity(0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Color(0xFF00E5FF), size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Advanced rank verification aa raha hai! Abhi ke liye rank skip karein — profile pe sirf game tag dikhega.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

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

                      // ✅ COMING SOON: Rank chips disabled — tap shows Snackbar
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
                          // ✅ COMING SOON: Rank chips show lock icon and disabled state
                          ..._dynamicRanks.map((rank) {
                            final isSelected = _rankController.text.trim() == rank;
                            final gameColor = MobileGamesRankData.getGameColor(_selectedRankGame);
                            return InkWell(
                              onTap: _showRankComingSoonBanner, // ✅ NEW: Show coming soon
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
                                    // ✅ NEW: Lock icon to show disabled
                                    const SizedBox(width: 5),
                                    const Icon(Icons.lock_rounded, size: 11, color: Colors.amber),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),

                      // ✅ COMING SOON: Screenshot upload box — tap shows Snackbar
                      // (Only show if user previously had a rank selected — for existing users)
                      if (_rankController.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10141D),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white24,
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
                                        onPressed: _showRankComingSoonBanner, // ✅ NEW
                                        icon: const Icon(Icons.edit_rounded, size: 14, color: Colors.white38),
                                        label: const Text('تصویر تبدیل کریں (Coming Soon)', style: TextStyle(color: Colors.white38, fontSize: 11.5)),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.white24),
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
                                        onPressed: _showRankComingSoonBanner, // ✅ NEW
                                        icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.white38),
                                        label: const Text('نیا اسکرین شاٹ (Coming Soon)', style: TextStyle(color: Colors.white38, fontSize: 11.5)),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.white24),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                InkWell(
                                  onTap: _showRankComingSoonBanner, // ✅ NEW
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF161B26),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white24,
                                        style: BorderStyle.solid,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Column(
                                      children: [
                                        Icon(Icons.lock_clock_rounded, color: Colors.white38, size: 36),
                                        SizedBox(height: 8),
                                        Text(
                                          'Rank Screenshot Upload — Coming Soon',
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Advanced verification feature aa raha hai',
                                          style: TextStyle(
                                            color: Colors.white38,
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

/// Bottom Sheet for adding or verifying game ranks
class AddVerifyGamerRankSheet extends StatefulWidget {
  final GamerUser user;
  const AddVerifyGamerRankSheet({super.key, required this.user});

  @override
  State<AddVerifyGamerRankSheet> createState() => _AddVerifyGamerRankSheetState();
}

typedef AddVerifyGameRankSheet = AddVerifyGamerRankSheet;

class _AddVerifyGamerRankSheetState extends State<AddVerifyGamerRankSheet> {
  late String _selectedGame;
  String _selectedRank = '';
  final TextEditingController _uidController = TextEditingController();
  File? _proofFile;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedGame = MobileGamesRankData.games.first;
  }

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  List<String> get _ranks => MobileGamesRankData.getRanksForGame(_selectedGame);

  Future<void> _pickProof() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _proofFile = File(picked.path));
    }
  }

  Future<void> _submitRank() async {
    final uid = widget.user.uid;
    final gameId = _uidController.text.trim();
    if (_selectedRank.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rank'), backgroundColor: GamerTheme.redAccent),
      );
      return;
    }
    if (gameId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter in-game Character ID / UID'), backgroundColor: GamerTheme.redAccent),
      );
      return;
    }
    if (_proofFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload screenshot proof of your rank'), backgroundColor: GamerTheme.redAccent),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      String proofUrl = '';
      try {
        proofUrl = await GamerAuthService().uploadRankScreenshot(_proofFile!, uid);
      } catch (e) {
        debugPrint('Upload rank proof error: $e');
      }

      final newRank = UserGameRank(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        gameName: _selectedGame,
        gameId: gameId,
        claimedRank: _selectedRank,
        screenshotUrl: proofUrl,
        status: 'pending',
        submittedAt: DateTime.now(),
        ownerUid: uid,
      );

      final updatedGames = List<UserGameRank>.from(widget.user.games)
        ..removeWhere((g) => g.gameName.toLowerCase() == _selectedGame.toLowerCase())
        ..add(newRank);

      try {
        await SupabaseService.client.from('users').update({
          'games': updatedGames.map((g) => g.toMap()).toList(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', uid);
      } catch (_) {}

      await GamerAuthService().refreshCurrentGamer();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_selectedGame rank submitted for verification! 🎮'),
            backgroundColor: GamerTheme.neonGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: GamerTheme.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_rounded, color: Color(0xFF00E5FF), size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Add / Verify Game Rank',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: GamerTheme.cardElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GamerTheme.borderLight),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedGame,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF161B26),
                  items: MobileGamesRankData.games.map((g) {
                    return DropdownMenuItem(
                      value: g,
                      child: Text(
                        g,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedGame = val;
                        _selectedRank = '';
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Select Your Rank:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _ranks.map((r) {
                final isSel = _selectedRank == r;
                return ChoiceChip(
                  label: Text(r, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  selected: isSel,
                  selectedColor: const Color(0xFF00FF88),
                  backgroundColor: GamerTheme.surfaceDark,
                  onSelected: (val) {
                    if (val) setState(() => _selectedRank = r);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _uidController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'In-Game Character ID / UID',
                hintStyle: const TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                prefixIcon: const Icon(Icons.sports_esports_rounded, color: Color(0xFF00E5FF), size: 18),
                filled: true,
                fillColor: GamerTheme.cardElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickProof,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GamerTheme.cardElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _proofFile != null ? const Color(0xFF00FF88) : GamerTheme.borderLight),
                ),
                child: Row(
                  children: [
                    Icon(
                      _proofFile != null ? Icons.check_circle_rounded : Icons.add_photo_alternate_rounded,
                      color: _proofFile != null ? const Color(0xFF00FF88) : const Color(0xFF00E5FF),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _proofFile != null ? 'Screenshot Proof Attached' : 'Upload Rank Screenshot Proof',
                        style: TextStyle(
                          color: _proofFile != null ? const Color(0xFF00FF88) : Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRank,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Submit for Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}