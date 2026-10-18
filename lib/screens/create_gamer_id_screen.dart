// ═══════════════════════════════════════════════════════════════════════════════
// EXACT DIFF:
// 1. Added auto Language Selection Dialog on screen load for new users (!isEditing).
// 2. Added easy_localization, ThemeService, and LanguageService integrations.
// 3. Replaced .eq('id', uid) with .or('id.eq.$uid,uid.eq.$uid') on users table.
// 4. Fully localized into 7 languages via .tr().
// ═══════════════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/gamer_theme.dart';
import '../constants/mobile_games_rank_data.dart';
import '../models/gamer_user_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/supabase_service.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
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

  void _showNewUserLanguageDialog(BuildContext context) {
    final languages = [
      {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
      {'code': 'ur', 'name': 'اردو', 'flag': '🇵🇰'},
      {'code': 'ro', 'name': 'Roman', 'flag': '🌐'},
      {'code': 'hi', 'name': 'हिंदी', 'flag': '🇮🇳'},
      {'code': 'ar', 'name': 'العربية', 'flag': '🇸🇦'},
      {'code': 'zh', 'name': '中文', 'flag': '🇨🇳'},
      {'code': 'bn', 'name': 'বাংলা', 'flag': '🇧🇩'},
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: GamerTheme.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: GamerTheme.neonGreen.withOpacity(0.5), width: 1.5),
          ),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GamerTheme.neonGreen.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.language_rounded, color: GamerTheme.neonGreen, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                'choose_language'.tr(),
                style: const TextStyle(
                  color: GamerTheme.textWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'select_language_subtitle'.tr(),
                style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: languages.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final lang = languages[index];
                final isCurrent = context.locale.languageCode == lang['code'];

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final code = lang['code']!;
                    await context.setLocale(Locale(code));
                    try {
                      await LanguageService.setLanguage(code);
                    } catch (_) {}

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? GamerTheme.neonGreen.withOpacity(0.2)
                          : GamerTheme.cardElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent ? GamerTheme.neonGreen : GamerTheme.borderLight,
                        width: isCurrent ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(lang['flag']!, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          lang['name']!,
                          style: TextStyle(
                            color: isCurrent ? GamerTheme.neonGreen : GamerTheme.textWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showLockedItemBanner(String itemName) {
    _lockedItemBannerTimer?.cancel();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('item_locked_banner'.tr(args: [itemName])),
        backgroundColor: const Color(0xFF1877F2),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'btn_store'.tr(),
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
      SnackBar(
        content: Row(
          children: [
            const Text('🚀', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'rank_coming_soon_banner'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1877F2),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
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

    if (!widget.isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showNewUserLanguageDialog(context);
        }
      });
    }
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
        _usernameFeedback = 'err_username_format'.tr();
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameFeedback = 'checking_availability'.tr();
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
        _usernameFeedback = available ? 'username_available'.tr() : 'username_taken'.tr();
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
          content: Text('err_pick_image'.tr(args: [e.toString()])),
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
          content: Text('err_pick_cover'.tr(args: [e.toString()])),
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
        SnackBar(
          content: Text('err_choose_available_username'.tr()),
          backgroundColor: GamerTheme.redAccent,
        ),
      );
      return;
    }

    final uid = GamerAuthService().currentUid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('err_session_expired'.tr()),
          backgroundColor: GamerTheme.redAccent,
        ),
      );
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('err_photo_upload_failed'.tr()),
                backgroundColor: GamerTheme.redAccent,
              ),
            );
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('err_cover_upload_failed'.tr()),
                backgroundColor: GamerTheme.redAccent,
              ),
            );
          }
          setState(() => _isSaving = false);
          return;
        }
      }

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
          finalRankStatus = widget.existingUser?.rankStatus.isNotEmpty == true
              ? widget.existingUser!.rankStatus
              : 'pending';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('err_save_gamer_id'.tr(args: [e.toString()])),
            backgroundColor: GamerTheme.redAccent,
          ),
        );
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditing
              ? 'msg_gamer_id_updated'.tr()
              : 'msg_welcome_gamer'.tr(args: [rawUsername])),
          backgroundColor: GamerTheme.neonGreen,
        ),
      );

      if (widget.isEditing) {
        try {
          await GamerAuthService().refreshCurrentGamer();
        } catch (_) {}
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const GamerMainNavigationScreen()),
          (route) => false,
        );
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
        title: Text(isEditing ? 'title_edit_gamer_id'.tr() : 'title_create_gamer_id'.tr()),
        automaticallyImplyLeading: isEditing,
        actions: [
          if (isEditing)
            TextButton(
              onPressed: _isSaving ? null : _saveGamerId,
              child: Text('save'.tr(), style: const TextStyle(color: GamerTheme.accentOrange, fontWeight: FontWeight.bold)),
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 5),
                              Text(
                                'change_cover_photo'.tr(),
                                style: const TextStyle(
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
                              label: Text(
                                'upload_photo_gallery'.tr(),
                                style: const TextStyle(
                                  color: GamerTheme.accentOrange,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'pro_gamer_avatar_presets'.tr(),
                              style: const TextStyle(
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
                                Row(
                                  children: [
                                    const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      'avatar_frame_title'.tr(),
                                      style: const TextStyle(
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
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.storefront_rounded, color: GamerTheme.neonGreen, size: 12),
                                        const SizedBox(width: 4),
                                        Text(
                                          'coin_store_caps'.tr(),
                                          style: const TextStyle(
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
                                    'name': 'frame_none'.tr(),
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
                            Row(
                              children: [
                                const Icon(Icons.military_tech_rounded, color: GamerTheme.accentBlue, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'gamer_badge_title'.tr(),
                                  style: const TextStyle(
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
                                    'name': 'frame_none'.tr(),
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
                                              Text('frame_none'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 11))
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
                      Row(
                        children: [
                          Text(
                            'field_username_label'.tr(),
                            style: const TextStyle(color: GamerTheme.accentOrange, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
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
                          hintText: 'gamer_handle',
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
                          if (clean.isEmpty) return 'err_username_required'.tr();
                          if (clean.length < 3) return 'err_username_min'.tr();
                          if (clean.length > 15) return 'err_username_max'.tr();
                          if (!RegExp(r'^[a-z0-9_]+$').hasMatch(clean)) {
                            return 'err_username_chars'.tr();
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
                      Text(
                        'field_display_name_label'.tr(),
                        style: const TextStyle(color: GamerTheme.textGray, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
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
                          if ((val ?? '').trim().isEmpty) return 'err_display_name_required'.tr();
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'field_fav_game_label'.tr(),
                        style: const TextStyle(color: GamerTheme.textGray, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.military_tech_rounded, color: Color(0xFFFF8A00), size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'my_game_rank_proof'.tr(),
                                style: const TextStyle(
                                  color: GamerTheme.textGray,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1877F2), Color(0xFF00E5FF)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🚀', style: TextStyle(fontSize: 10)),
                                const SizedBox(width: 4),
                                Text(
                                  'coming_soon_caps'.tr(),
                                  style: const TextStyle(
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B26),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1877F2).withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFF00E5FF), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'rank_verification_info'.tr(),
                                style: const TextStyle(
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'select_rank_label'.tr(),
                            style: const TextStyle(
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
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
                                    'skip_no_rank'.tr(),
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
                          ..._dynamicRanks.map((rank) {
                            final isSelected = _rankController.text.trim() == rank;
                            final gameColor = MobileGamesRankData.getGameColor(_selectedRankGame);
                            return InkWell(
                              onTap: _showRankComingSoonBanner,
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
                                    const SizedBox(width: 5),
                                    const Icon(Icons.lock_rounded, size: 11, color: Colors.amber),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
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
                              if (_rankStatus.toLowerCase() == 'pending') ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF332B00),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFFFD700)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.hourglass_top_rounded, color: Color(0xFFFFD700), size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'rank_status_pending'.tr(),
                                          style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 11.5),
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
                                  child: Row(
                                    children: [
                                      const Icon(Icons.verified_rounded, color: Color(0xFF00FF88), size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'rank_status_verified'.tr(),
                                          style: const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 11.5),
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
                                      Row(
                                        children: [
                                          const Icon(Icons.error_outline_rounded, color: Color(0xFFFF4655), size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'rank_status_rejected_msg'.tr(),
                                              style: const TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_rankRejectReason.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'reason_prefix'.tr(args: [_rankRejectReason]),
                                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161B26),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF2E384D)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'screenshot_requirement_hint'.tr(),
                                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
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
                                        onPressed: _showRankComingSoonBanner,
                                        icon: const Icon(Icons.edit_rounded, size: 14, color: Colors.white38),
                                        label: Text('btn_change_photo_coming_soon'.tr(), style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
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
                                        onPressed: _showRankComingSoonBanner,
                                        icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.white38),
                                        label: Text('btn_new_screenshot_coming_soon'.tr(), style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
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
                                  onTap: _showRankComingSoonBanner,
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
                                    child: Column(
                                      children: [
                                        const Icon(Icons.lock_clock_rounded, color: Colors.white38, size: 36),
                                        const SizedBox(height: 8),
                                        Text(
                                          'rank_upload_coming_soon_title'.tr(),
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'rank_upload_coming_soon_sub'.tr(),
                                          style: const TextStyle(
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'field_bio_label'.tr(),
                            style: const TextStyle(color: GamerTheme.textGray, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
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
                        decoration: InputDecoration(
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 24),
                            child: Icon(Icons.edit_note_rounded, color: GamerTheme.textMuted),
                          ),
                          hintText: 'bio_hint'.tr(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Text(
                            'field_character_id_label'.tr(),
                            style: const TextStyle(color: GamerTheme.textGray, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.lock_rounded, size: 14, color: GamerTheme.textMuted),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _gameIdController,
                        style: const TextStyle(color: GamerTheme.textWhite),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.sports_esports_rounded, color: GamerTheme.accentOrange),
                          hintText: '12345',
                          helperText: 'helper_character_uid'.tr(),
                          helperStyle: const TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 32),
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
                                          isEditing ? 'btn_save_changes'.tr() : 'btn_save_changes_join'.tr(),
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
        SnackBar(content: Text('err_select_rank'.tr()), backgroundColor: GamerTheme.redAccent),
      );
      return;
    }
    if (gameId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('err_enter_character_uid'.tr()), backgroundColor: GamerTheme.redAccent),
      );
      return;
    }
    if (_proofFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('err_upload_proof'.tr()), backgroundColor: GamerTheme.redAccent),
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
            content: Text('msg_rank_submitted'.tr(args: [_selectedGame])),
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
                Text(
                  'title_add_verify_rank'.tr(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
            Text('select_your_rank_label'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
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
                hintText: 'field_character_id_label'.tr(),
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
                        _proofFile != null ? 'proof_attached'.tr() : 'upload_rank_proof'.tr(),
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
                    : Text('btn_submit_verification'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
