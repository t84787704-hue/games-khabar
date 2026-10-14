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

  Timer? _debounceTimer;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String _usernameFeedback = '';

  static const String _defaultBgmiCoverUrl =
      'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=1200&auto=format&fit=crop&q=80';

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
        SnackBar(content: Text('Could not pick image: $e'), backgroundColor: GamerTheme.redAccent),
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
        SnackBar(content: Text('Could not pick cover image: $e'), backgroundColor: GamerTheme.redAccent),
      );
    }
  }

  Future<void> _pickRankScreenshot(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
      if (picked != null) {
        setState(() {
          _pickedRankScreenshot = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick screenshot: $e'), backgroundColor: GamerTheme.redAccent),
        );
      }
    }
  }

  void _showRankScreenshotPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10141D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Upload Rank Screenshot Proof', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              const Text('اسکرین شاٹ میں گیم کی اصل ID اور Rank صاف نظر آنا چاہیے', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please choose an available username'), backgroundColor: GamerTheme.redAccent));
      return;
    }
    final uid = GamerAuthService().currentUid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication session expired. Please log in again.'), backgroundColor: GamerTheme.redAccent));
      return;
    }
    bool saveSucceeded = false;
    setState(() => _isSaving = true);
    try {
      String finalPhotoUrl = _photoUrl;
      if (_pickedImageFile != null) {
        final uploaded = await GamerAuthService().uploadProfilePhoto(_pickedImageFile!, uid);
        if (uploaded.isNotEmpty) {
          finalPhotoUrl = uploaded;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Profile photo upload fail! Try again.'), backgroundColor: GamerTheme.redAccent));
          }
          setState(() => _isSaving = false);
          return;
        }
      }

      String finalCoverUrl = _coverUrl;
      if (_pickedCoverFile != null) {
        final uploaded = await GamerAuthService().uploadCoverPhoto(_pickedCoverFile!, uid);
        if (uploaded.isNotEmpty) {
          finalCoverUrl = uploaded;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Cover photo upload fail! Try again.'), backgroundColor: GamerTheme.redAccent));
          }
          setState(() => _isSaving = false);
          return;
        }
      }

      // ✅ FIX: Purani cache delete - yahi tumhara asal bug tha
      try {
        if (_photoUrl.isNotEmpty && _photoUrl != finalPhotoUrl) {
          await CachedNetworkImage.evictFromCache(_photoUrl);
        }
        if (_coverUrl.isNotEmpty && _coverUrl != finalCoverUrl) {
          await CachedNetworkImage.evictFromCache(_coverUrl);
        }
        if (finalPhotoUrl.isNotEmpty) {
          await CachedNetworkImage.evictFromCache(finalPhotoUrl);
        }
        if (finalCoverUrl.isNotEmpty) {
          await CachedNetworkImage.evictFromCache(finalCoverUrl);
        }
        imageCache.clear();
        imageCache.clearLiveImages();
      } catch (_) {}

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
          finalRankScreenshot = await GamerAuthService().uploadRankScreenshot(_pickedRankScreenshot!, uid);
          finalRankStatus = 'pending';
          finalRankRejectReason = '';
          isRankVerified = false;
        } else if (finalRankScreenshot.isNotEmpty) {
          finalRankStatus = widget.existingUser?.rankStatus.isNotEmpty == true ? widget.existingUser!.rankStatus : 'pending';
        } else {
          finalRankStatus = 'none';
          finalRankScreenshot = '';
          isRankVerified = false;
        }
      } else {
        finalRank = '';
        finalRankStatus = 'none';
        finalRankScreenshot = '';
        isRankVerified = false;
      }

      final gamerUser = GamerUser(
        uid: uid,
        username: rawUsername,
        displayName: _displayNameController.text.trim().isNotEmpty ? _displayNameController.text.trim() : rawUsername,
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

      if (finalPhotoUrl.isNotEmpty) {
        _photoUrl = finalPhotoUrl;
      }
      if (finalCoverUrl.isNotEmpty) {
        _coverUrl = finalCoverUrl;
      }

      GamerAuthService().currentGamerNotifier.value = gamerUser;
      saveSucceeded = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save Gamer ID: $e'), backgroundColor: GamerTheme.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }

    if (saveSucceeded) {
      if (!mounted) return;
      setState(() {
        _pickedImageFile = null;
        _pickedCoverFile = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.isEditing ? 'Gamer ID updated!' : 'Welcome to Gamers ID, @$rawUsername! 🎮'), backgroundColor: GamerTheme.neonGreen));
      if (widget.isEditing) {
        try {
          await GamerAuthService().refreshCurrentGamer();
        } catch (_) {}
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const GamerMainNavigationScreen()), (route) => false);
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
                Stack(
                  children: [
                    Container(
                      height: 175,
                      width: double.infinity,
                      decoration: const BoxDecoration(color: Color(0xFF0F172A)),
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
                                  gradient: LinearGradient(colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                ),
                              ),
                            ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Colors.black.withOpacity(0.5), Colors.black.withOpacity(0.2), GamerTheme.bgDark.withOpacity(0.85)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 12,
                      child: InkWell(
                        onTap: _pickCoverFromGallery,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white38, width: 1), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 6)]),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14), SizedBox(width: 5), Text('Change Cover Photo', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))]),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: GamerTheme.accentOrange.withOpacity(0.45), blurRadius: 18, spreadRadius: 3)]),
                                  child: GamerAvatar(
                                    photoUrl: _photoUrl,
                                    imageFile: _pickedImageFile,
                                    displayName: _displayNameController.text.isNotEmpty ? _displayNameController.text : 'F',
                                    radius: 48,
                                    hasGlow: true,
                                    borderColor: GamerTheme.accentOrange,
                                    frameId: _selectedFrame,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: InkWell(
                                    onTap: _pickImageFromGallery,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(padding: const EdgeInsets.all(7), decoration: const BoxDecoration(gradient: GamerTheme.flameOrangeGradient, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 4)]), child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _pickImageFromGallery,
                              icon: const Icon(Icons.photo_library_rounded, size: 16, color: GamerTheme.accentOrange),
                              label: const Text('Upload Photo From Gallery', style: TextStyle(color: GamerTheme.accentOrange, fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 10),
                            const Text('PRO GAMER AVATAR PRESETS', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
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
                                            gradient: LinearGradient(colors: preset['bg'] as List<Color>, begin: Alignment.topLeft, end: Alignment.bottomRight),
                                            border: Border.all(color: isSelected ? GamerTheme.accentOrange : Colors.white24, width: isSelected ? 2.5 : 1),
                                            boxShadow: isSelected ? [BoxShadow(color: GamerTheme.accentOrange.withOpacity(0.5), blurRadius: 8, spreadRadius: 1)] : null,
                                          ),
                                          child: Center(child: Icon(preset['icon'] as IconData, color: preset['color'] as Color, size: 22)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(preset['label'] as String, style: TextStyle(color: isSelected ? GamerTheme.accentOrange : Colors.white70, fontSize: 10, fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600)),
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
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: GamerTheme.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GamerTheme.borderDark)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(children: [Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 18), SizedBox(width: 6), Text('AVATAR FRAME', style: TextStyle(color: GamerTheme.textWhite, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8))]),
                                InkWell(
                                  onTap: () async {
                                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CoinStoreScreen()));
                                    _loadStorePerks();
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: GamerTheme.neonGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: GamerTheme.neonGreen.withOpacity(0.5))),
                                    child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.storefront_rounded, color: GamerTheme.neonGreen, size: 12), SizedBox(width: 4), Text('COIN STORE', style: TextStyle(color: GamerTheme.neonGreen, fontSize: 10, fontWeight: FontWeight.w900))]),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(children: [const Text('USERNAME (Unique Gamer Handle)', style: TextStyle(color: GamerTheme.accentOrange, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8)), const SizedBox(width: 6), const Icon(Icons.verified, color: Color(0xFF00E676), size: 16)]),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _usernameController,
                        onChanged: _onUsernameChanged,
                        style: const TextStyle(color: GamerTheme.textWhite, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(prefixIcon: const Icon(Icons.alternate_email_rounded, color: GamerTheme.accentOrange), hintText: 'fua', suffixIcon: _isCheckingUsername ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: GamerTheme.accentOrange))) : const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 22)),
                      ),
                      const SizedBox(height: 20),
                      const Text('DISPLAY NAME', style: TextStyle(color: GamerTheme.textGray, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                      const SizedBox(height: 8),
                      TextFormField(controller: _displayNameController, style: const TextStyle(color: GamerTheme.textWhite), decoration: const InputDecoration(prefixIcon: Icon(Icons.person_rounded, color: GamerTheme.textMuted), hintText: 'e.g. Fauji Gamer, Toxic Soul'), validator: (val) => (val ?? '').trim().isEmpty ? 'Display Name is required' : null),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveGamerId,
                          style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 4),
                          child: Ink(
                            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF8A00), Color(0xFFFF5200)], begin: Alignment.centerLeft, end: Alignment.centerRight), borderRadius: BorderRadius.circular(14)),
                            child: Center(child: _isSaving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.check_rounded, color: Colors.white, size: 20), const SizedBox(width: 8), Text(isEditing ? 'Save Changes' : 'Save Changes & Join', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))])),
                          ),
                        ),
                      ),
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