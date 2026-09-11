import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_user_model.dart';
import '../models/gamer_post_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_social_service.dart';
import '../widgets/gamer_avatar.dart';
import '../widgets/post_card.dart';
import '../widgets/rank_badge_widget.dart';
import '../services/verification_service.dart';
import '../models/challenge_model.dart';
import '../services/challenge_service.dart';
import '../services/profile_service.dart';
import '../widgets/posts_tab.dart';
import 'create_gamer_id_screen.dart';
import 'followers_following_screen.dart';
import 'gamer_auth_screen.dart';
import 'saved_news_tab_screen.dart';
import 'verification_screen.dart';
import '../widgets/coin_history_sheet.dart';

class GamerProfileScreen extends StatefulWidget {
  final String? userId; // If null, displays currently logged in user's profile

  const GamerProfileScreen({super.key, this.userId});

  @override
  State<GamerProfileScreen> createState() => _GamerProfileScreenState();
}

class _GamerProfileScreenState extends State<GamerProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GamerAuthService _authService = GamerAuthService();
  final GamerSocialService _socialService = GamerSocialService();

  VerificationProgress? _liveProgress;
  bool _isCheckingVerification = false;
  String? _lastCheckedUid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showChangeCoverSheet(BuildContext context, GamerUser user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: GamerTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: GamerTheme.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Change Cover Photo',
                  style: TextStyle(
                    color: GamerTheme.textWhite,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose a custom banner or select a BGMI theme',
                  style: TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: GamerTheme.accentOrange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: GamerTheme.accentOrange, size: 20),
                  ),
                  title: const Text('Choose from Gallery', style: TextStyle(color: GamerTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Upload your custom gaming banner', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadCoverPhoto(user);
                  },
                ),
                const Divider(color: GamerTheme.borderDark, height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: GamerTheme.accentBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.sports_esports_rounded, color: GamerTheme.accentBlue, size: 20),
                  ),
                  title: const Text('BGMI Erangel Scrims Banner', style: TextStyle(color: GamerTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Official action theme', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _setPresetCover(user, 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=1200&auto=format&fit=crop&q=80');
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.military_tech_rounded, color: Color(0xFFFFD700), size: 20),
                  ),
                  title: const Text('BGMI Battlegrounds Cyber Banner', style: TextStyle(color: GamerTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Neon battleground style', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _setPresetCover(user, 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?w=1200&auto=format&fit=crop&q=80');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadCoverPhoto(GamerUser user) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (picked == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('Uploading cover photo...'),
            ],
          ),
          duration: Duration(seconds: 4),
        ),
      );

      final file = File(picked.path);
      final uploadedUrl = await _authService.uploadCoverPhoto(file, user.uid);
      final finalUrl = uploadedUrl.isNotEmpty ? uploadedUrl : '';

      if (finalUrl.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'coverUrl': finalUrl,
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cover photo updated successfully!'),
              backgroundColor: GamerTheme.accentGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not upload cover photo: $e'),
            backgroundColor: GamerTheme.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _setPresetCover(GamerUser user, String coverUrl) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'coverUrl': coverUrl,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('BGMI cover banner applied!'),
            backgroundColor: GamerTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set cover: $e'),
            backgroundColor: GamerTheme.redAccent,
          ),
        );
      }
    }
  }

  void _triggerLiveVerificationCheck(GamerUser user) {
    if (_lastCheckedUid == user.uid && _liveProgress != null) return;
    _lastCheckedUid = user.uid;
    _liveProgress = VerificationService.getProgressFromUser(user);
    
    // Asynchronously perform live count check and auto-verify if eligible
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() => _isCheckingVerification = true);
      final wasVerified = user.isVerified;
      final progress = await VerificationService.checkAndAutoVerify(user);
      if (!mounted) return;
      setState(() {
        _liveProgress = progress;
        _isCheckingVerification = false;
      });

      // If user earned the tick just now, show celebratory animation!
      if (!wasVerified && progress.isVerified) {
        _showCelebrationDialog();
      }
    });
  }

  Future<void> _manualRefreshVerification(GamerUser user) async {
    setState(() => _isCheckingVerification = true);
    final wasVerified = user.isVerified;
    final progress = await VerificationService.checkAndAutoVerify(user);
    if (!mounted) return;
    setState(() {
      _liveProgress = progress;
      _isCheckingVerification = false;
    });

    if (!wasVerified && progress.isVerified) {
      _showCelebrationDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(progress.isVerified
              ? '🎉 You are officially verified!'
              : '${progress.completedRequirementsCount} of 6 requirements completed. Keep going!'),
          backgroundColor: progress.isVerified ? GamerTheme.accentBlue : GamerTheme.cardElevated,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showCelebrationDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Celebration',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.blue.withOpacity(0.6), width: 2),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                // Glowing blue verified badge
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withOpacity(0.15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.4),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Colors.blue,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '🎉 CONGRATULATIONS! 🎉',
                  style: TextStyle(
                    color: GamerTheme.accentOrange,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You Are Now Verified!',
                  style: TextStyle(
                    color: GamerTheme.textWhite,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'You have completed all community requirements! The official Blue Tick ✓ has been permanently added to your Gamer ID and all your posts.',
                  style: TextStyle(
                    color: GamerTheme.textGray,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Awesome! Let\'s Flex 🎮',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLinkGameIdDialog(GamerUser user) {
    final controller = TextEditingController(text: user.gameId);
    String selectedGame = user.favoriteGame;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: GamerTheme.cardElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.sports_esports_rounded, color: GamerTheme.accentBlue, size: 22),
              SizedBox(width: 8),
              Text('Link Game ID', style: TextStyle(color: GamerTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Requirement 2: Link your Character UID or in-game nickname (e.g. BGMI: shadow_hunter, FF: 51293847).',
                style: TextStyle(color: GamerTheme.textGray, fontSize: 12, height: 1.3),
              ),
              const SizedBox(height: 16),
              const Text('GAME', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: GamerTheme.cardDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: GamerTheme.borderDark),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: GamerTheme.favoriteGames.contains(selectedGame) ? selectedGame : 'BGMI',
                    isExpanded: true,
                    dropdownColor: GamerTheme.cardElevated,
                    items: GamerTheme.favoriteGames.map((g) {
                      return DropdownMenuItem<String>(
                        value: g,
                        child: Text(g, style: const TextStyle(color: GamerTheme.textWhite, fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedGame = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('IN-GAME ID / CHARACTER UID', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                style: const TextStyle(color: GamerTheme.textWhite, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. shadow_hunter',
                  hintStyle: const TextStyle(color: GamerTheme.textMuted),
                  filled: true,
                  fillColor: GamerTheme.cardDark,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: GamerTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: GamerTheme.accentBlue),
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(ctx);
                await VerificationService.linkGameId(
                  userId: user.uid,
                  gameId: text,
                  gameName: selectedGame,
                );
                _manualRefreshVerification(user);
              },
              child: const Text('Save & Verify', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showVerificationRequirementsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: GamerTheme.borderDark),
        ),
        title: const Row(
          children: [
            Icon(Icons.verified, color: Colors.blue, size: 22),
            SizedBox(width: 8),
            Text('Verification Requirements', style: TextStyle(color: GamerTheme.textWhite, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Gamers ID requires authenticity and community standing before awarding the official Blue Tick ✓:',
                style: TextStyle(color: GamerTheme.textGray, fontSize: 12.5, height: 1.35),
              ),
              const SizedBox(height: 16),
              _buildRuleItem('1. Complete Profile', 'Must have a real photo avatar (not placeholder letter) and a gaming bio.'),
              const SizedBox(height: 12),
              _buildRuleItem('2. Linked Game ID', 'Must link at least 1 verified in-game Character ID / UID (e.g. BGMI: shadow_hunter).'),
              const SizedBox(height: 12),
              _buildRuleItem('3. Active Gamer', 'Must publish at least 10 gaming posts and receive 100+ likes from the community.'),
              const SizedBox(height: 12),
              _buildRuleItem('4. Community Standing', 'Must have 20+ followers to prove community trust.'),
              const SizedBox(height: 12),
              _buildRuleItem('5. Account Age (Trust)', 'Account must be at least 15 days old to prevent bots and spammers.'),
              const SizedBox(height: 12),
              _buildRuleItem('6. Clean Record', 'Zero toxic conduct reports or suspensions in the last 30 days.'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got It', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.check_circle, color: Colors.blue, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: GamerTheme.textWhite, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11.5, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  void _show1v1ChallengeDialog(GamerUser targetUser) {
    final currentGamer = _authService.currentGamer;
    if (currentGamer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create your Gamer ID to challenge players!')),
      );
      return;
    }

    String selectedGame = targetUser.favoriteGame.isNotEmpty ? targetUser.favoriteGame : 'BGMI';
    String selectedMode = 'TDM 1v1 Warehouse';
    String selectedWeapon = 'M416 Only';

    final modes = ['TDM 1v1 Warehouse', 'TDM 1v1 Hangar', 'Room 1v1 Erangel', 'Sniper 1v1 Ruins'];
    final weapons = ['M416 Only', 'Sniper / AWM Only', 'Shotgun Only', 'All Weapons Allowed'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF14101A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFFF2D55), width: 1.5),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2D55).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Text('⚔️', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1v1 CHALLENGE',
                      style: TextStyle(
                        color: Color(0xFFFF2D55),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'vs ${targetUser.displayName}',
                      style: const TextStyle(
                        color: GamerTheme.textWhite,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GamerTheme.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: GamerTheme.borderDark),
                  ),
                  child: Row(
                    children: [
                      GamerAvatar(
                        photoUrl: targetUser.photoUrl,
                        displayName: targetUser.displayName,
                        radius: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              targetUser.displayName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'Rank: ${targetUser.rank} • UID: ${targetUser.gameId.isEmpty ? "Not set" : targetUser.gameId}',
                              style: const TextStyle(color: GamerTheme.textGray, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('SELECT MAP / MODE', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: GamerTheme.cardDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: GamerTheme.borderDark),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedMode,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1B1424),
                      items: modes.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(color: Colors.white, fontSize: 13)))).toList(),
                      onChanged: (v) => setDialogState(() => selectedMode = v ?? selectedMode),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('WEAPON RULE', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: GamerTheme.cardDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: GamerTheme.borderDark),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedWeapon,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1B1424),
                      items: weapons.map((w) => DropdownMenuItem(value: w, child: Text(w, style: const TextStyle(color: Colors.white, fontSize: 13)))).toList(),
                      onChanged: (v) => setDialogState(() => selectedWeapon = v ?? selectedWeapon),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF2D55).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF2D55).withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Color(0xFFFF2D55), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'An instant invite will appear in their notifications to accept or decline.',
                          style: TextStyle(color: GamerTheme.textGray, fontSize: 11.5, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: GamerTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2D55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final challenge = GamerChallenge(
                  id: '',
                  challengerId: currentGamer.uid,
                  challengerName: currentGamer.displayName,
                  challengerAvatar: currentGamer.photoUrl,
                  challengedId: targetUser.uid,
                  challengedName: targetUser.displayName,
                  challengedAvatar: targetUser.photoUrl,
                  game: selectedGame,
                  mode: selectedMode,
                  weaponRule: selectedWeapon,
                );
                await ChallengeService().sendChallenge(challenge);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('⚔️ 1v1 Challenge Sent to ${targetUser.displayName}!'),
                    backgroundColor: const Color(0xFFFF2D55),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flash_on_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('SEND 1v1 ⚔️', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareProfile(GamerUser user) {
    final text = '🎮 Check out ${user.displayName}\'s Gamer ID on Gamers ID!\n\n'
        'Handle: @${user.username}\n'
        'Game: ${user.favoriteGame} | Rank: ${user.rank}\n'
        'Bio: ${user.bio}\n\n'
        'Join the Mini Facebook for Gamers!';
    Share.share(text);
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GamerTheme.cardElevated,
        title: const Text('Log Out', style: TextStyle(color: GamerTheme.textWhite)),
        content: const Text('Are you sure you want to log out of Gamers ID?', style: TextStyle(color: GamerTheme.textGray)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: GamerTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GamerTheme.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await _authService.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const GamerAuthScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String count, String label, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            Text(
              count,
              style: const TextStyle(
                color: GamerTheme.textWhite,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: GamerTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _authService.currentUid ?? '';
    final targetUid = widget.userId ?? currentUid;
    final isOwnProfile = currentUid == targetUid;

    return StreamBuilder<GamerUser?>(
      stream: _authService.userProfileStream(targetUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: GamerTheme.bgDark,
            body: Center(child: CircularProgressIndicator(color: GamerTheme.accentBlue)),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return Scaffold(
            backgroundColor: GamerTheme.bgDark,
            appBar: AppBar(title: const Text('Gamer Profile')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sentiment_dissatisfied_rounded, color: GamerTheme.textMuted, size: 54),
                  const SizedBox(height: 12),
                  const Text('Gamer ID not found or not set up yet.', style: TextStyle(color: GamerTheme.textWhite)),
                  const SizedBox(height: 16),
                  if (isOwnProfile)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: GamerTheme.accentBlue),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CreateGamerIdScreen()),
                        );
                      },
                      child: const Text('Create Your Gamer ID', style: TextStyle(color: GamerTheme.bgDark, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          );
        }

        final gameColor = GamerTheme.gameColors[user.favoriteGame] ?? GamerTheme.accentBlue;
        final gameEmoji = GamerTheme.gameEmojis[user.favoriteGame] ?? '🎮';

        return Scaffold(
          backgroundColor: GamerTheme.bgDark,
          extendBody: false,
          extendBodyBehindAppBar: false,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 250,
                  pinned: true,
                  backgroundColor: GamerTheme.cardDark,
                  title: Text(
                    isOwnProfile ? 'My Gamer ID' : '@${user.username}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  actions: [
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('coin_wallets')
                          .doc(targetUid)
                          .snapshots(),
                      builder: (context, coinSnap) {
                        int coins = user.coins;
                        if (coinSnap.hasData && coinSnap.data!.exists) {
                          final data = coinSnap.data!.data() as Map<String, dynamic>? ?? {};
                          coins = (data['coins'] as num?)?.toInt() ?? user.coins;
                        }
                        return GestureDetector(
                          onTap: () => CoinHistorySheet.show(context, userId: targetUid),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFFFD700), width: 1.2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🪙', style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 4),
                                Text(
                                  'Coins: $coins',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD700),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(Icons.history_rounded, size: 13, color: Color(0xFFFFD700)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: GamerTheme.accentBlue),
                      onPressed: () => _shareProfile(user),
                    ),
                    if (isOwnProfile) ...[
                      IconButton(
                        tooltip: 'Saved Articles & Posts',
                        icon: const Icon(Icons.bookmark_rounded, color: GamerTheme.accentOrange),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                backgroundColor: GamerTheme.bgDark,
                                appBar: AppBar(
                                  backgroundColor: GamerTheme.bgDark,
                                  title: const Text('Saved Posts & News', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                                body: const SavedNewsTabScreen(),
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded, color: GamerTheme.redAccent),
                        onPressed: _confirmSignOut,
                      ),
                    ],
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // BGMI Pro Cover Banner
                        Container(
                          height: 175,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F172A),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: user.coverUrl.isNotEmpty
                                    ? user.coverUrl
                                    : 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=1200&auto=format&fit=crop&q=80',
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: const Color(0xFF0F172A),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: GamerTheme.accentOrange),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Image.network(
                                  'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=1200&auto=format&fit=crop&q=80',
                                  fit: BoxFit.cover,
                                ),
                              ),
                              // Cinematic overlay gradient for high contrast
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withOpacity(0.55),
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.65),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                              // GAMERS ID NETWORK Tag
                              Positioned(
                                left: 16,
                                top: 50,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(gameEmoji, style: const TextStyle(fontSize: 12)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'GAMERS ID NETWORK',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.95),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Change Cover Photo button
                              if (isOwnProfile)
                                Positioned(
                                  right: 14,
                                  bottom: 12,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _showChangeCoverSheet(context, user),
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.7),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.1),
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
                                            Icon(Icons.camera_alt_rounded, color: Colors.white, size: 13),
                                            SizedBox(width: 5),
                                            Text(
                                              'Change Cover Photo',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Avatar F overlapping cover with orange glow
                        Positioned(
                          top: 129,
                          left: 20,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF8A00).withOpacity(0.75),
                                  blurRadius: 20,
                                  spreadRadius: 4,
                                ),
                                BoxShadow(
                                  color: const Color(0xFFFF5200).withOpacity(0.45),
                                  blurRadius: 30,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: GamerAvatar(
                              photoUrl: user.photoUrl,
                              displayName: user.displayName,
                              radius: 46,
                              hasGlow: true,
                              borderColor: const Color(0xFFFF8A00),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // User Info & Badges Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display Name + Rank Badge (Only ACE gold badge next to Fua)
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.displayName,
                                style: const TextStyle(
                                  color: GamerTheme.textWhite,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            RankBadgeWidget(
                              badge: user.getRankBadge(),
                              size: 16,
                              showLabel: true,
                            ),
                            if (user.isVerifiedBlue || user.isVerified) ...[
                              const SizedBox(width: 5),
                              const Icon(Icons.verified, color: Color(0xFF1D9BF0), size: 18),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),

                        // @username
                        Text(
                          '@${user.username}',
                          style: const TextStyle(
                            color: GamerTheme.accentOrange,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        // Bio
                        if (user.bio.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            user.bio,
                            style: const TextStyle(
                              color: GamerTheme.textWhite,
                              fontSize: 13.5,
                              height: 1.35,
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Favorite Game Badge, Rank Chip & App Rank (auto)
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Favorite Game Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: gameColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: gameColor.withOpacity(0.6)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(gameEmoji, style: const TextStyle(fontSize: 13)),
                                  const SizedBox(width: 6),
                                  Text(
                                    user.favoriteGame,
                                    style: TextStyle(
                                      color: gameColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Rank Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: GamerTheme.cardElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: GamerTheme.borderLight),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.military_tech_rounded, color: GamerTheme.flameOrange, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.rank,
                                    style: const TextStyle(
                                      color: GamerTheme.flameOrange,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // App Rank Badge (Auto points calculation)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome_rounded, color: Color(0xFF00E5FF), size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'App Rank: ${user.appRank}',
                                    style: const TextStyle(
                                      color: Color(0xFF00E5FF),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Text(
                                    '(auto)',
                                    style: TextStyle(
                                      color: Color(0xFF8B949E),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Verified Game Ranks Badges
                            ...user.games
                                .where((g) => g.isVerified || g.status == 'approved')
                                .map((g) {
                              final gColor = _getGameAccentColor(g.gameName);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: gColor.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: gColor.withOpacity(0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_getGameIcon(g.gameName), color: gColor, size: 13),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${g.gameName}: ${g.verifiedRank.isNotEmpty ? g.verifiedRank : g.claimedRank}',
                                      style: TextStyle(
                                        color: gColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF00FF88), size: 12),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),

                        // Gamer Coins Balance & Full History Banner (Tap to view complete history)
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('coin_wallets')
                              .doc(targetUid)
                              .snapshots(),
                          builder: (context, coinSnap) {
                            int coins = user.coins;
                            if (coinSnap.hasData && coinSnap.data!.exists) {
                              final data = coinSnap.data!.data() as Map<String, dynamic>? ?? {};
                              coins = (data['coins'] as num?)?.toInt() ?? user.coins;
                            }
                            return InkWell(
                              onTap: () => CoinHistorySheet.show(context, userId: targetUid),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                margin: const EdgeInsets.only(top: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFFFFD700).withOpacity(0.14),
                                      const Color(0xFF1E293B),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFD700).withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Text('🪙', style: TextStyle(fontSize: 18)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'G-COINS WALLET',
                                            style: TextStyle(
                                              color: GamerTheme.textMuted,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$coins Coins',
                                            style: const TextStyle(
                                              color: Color(0xFFFFD700),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFD700),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.history_rounded, size: 14, color: Colors.black),
                                          SizedBox(width: 4),
                                          Text(
                                            'Coin History',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        // Followers / Following / Posts Counts
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: GamerTheme.cardDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: GamerTheme.borderDark),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              StreamBuilder<List<ProfileFeedItem>>(
                                stream: ProfileService().getUserPostsAndClipsStream(
                                  userId: user.uid,
                                  username: user.username,
                                ),
                                builder: (context, snap) {
                                  final totalCount = snap.hasData ? snap.data!.length : user.postsCount;
                                  return _buildStatColumn('$totalCount', 'Posts', () {
                                    _tabController.animateTo(0);
                                  });
                                },
                              ),
                              Container(height: 24, width: 1, color: GamerTheme.borderDark),
                              _buildStatColumn('${user.followersCount}', 'Followers', () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => FollowersFollowingScreen(
                                      userId: user.uid,
                                      displayName: user.displayName,
                                      initialTabIndex: 0,
                                    ),
                                  ),
                                );
                              }),
                              Container(height: 24, width: 1, color: GamerTheme.borderDark),
                              _buildStatColumn('${user.followingCount}', 'Following', () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => FollowersFollowingScreen(
                                      userId: user.uid,
                                      displayName: user.displayName,
                                      initialTabIndex: 1,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Action Buttons: Edit / Follow / Share
                        Row(
                          children: [
                            if (isOwnProfile) ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: GamerTheme.accentBlue,
                                    foregroundColor: GamerTheme.bgDark,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.edit_rounded, size: 18),
                                  label: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => CreateGamerIdScreen(isEditing: true, existingUser: user),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: GamerTheme.borderLight),
                                  foregroundColor: GamerTheme.textWhite,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                ),
                                icon: const Icon(Icons.share_rounded, size: 18, color: GamerTheme.accentOrange),
                                label: const Text('Share', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                onPressed: () => _shareProfile(user),
                              ),
                            ] else ...[
                              // Follow / Unfollow Button
                              Expanded(
                                flex: 3,
                                child: StreamBuilder<bool>(
                                  stream: _socialService.isFollowingStream(currentUid, user.uid),
                                  builder: (context, snap) {
                                    final isFollowing = snap.data ?? false;
                                    return ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isFollowing ? GamerTheme.cardElevated : GamerTheme.accentBlue,
                                        foregroundColor: isFollowing ? GamerTheme.textWhite : GamerTheme.bgDark,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          side: BorderSide(color: isFollowing ? GamerTheme.borderLight : Colors.transparent),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        elevation: 0,
                                      ),
                                      icon: Icon(
                                        isFollowing ? Icons.check_rounded : Icons.person_add_rounded,
                                        size: 16,
                                        color: isFollowing ? GamerTheme.neonGreen : GamerTheme.bgDark,
                                      ),
                                      label: Text(
                                        isFollowing ? 'Following' : 'Follow',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12.5,
                                          color: isFollowing ? GamerTheme.textWhite : GamerTheme.bgDark,
                                        ),
                                      ),
                                      onPressed: () async {
                                        if (currentUid.isEmpty) return;
                                        if (isFollowing) {
                                          await _socialService.unfollowUser(currentUid: currentUid, targetUid: user.uid);
                                        } else {
                                          await _socialService.followUser(currentUid: currentUid, targetUid: user.uid);
                                        }
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Prominent 1v1 Challenge Button (Red Outline)
                              Expanded(
                                flex: 3,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFFF2D55), width: 1.6),
                                    backgroundColor: const Color(0xFFFF2D55).withOpacity(0.12),
                                    foregroundColor: const Color(0xFFFF2D55),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  icon: const Text('⚔️', style: TextStyle(fontSize: 14)),
                                  label: const Text(
                                    '1v1 Battle',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12.5,
                                      color: Color(0xFFFF2D55),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  onPressed: () => _show1v1ChallengeDialog(user),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Share Button
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: GamerTheme.cardDark,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: const BorderSide(color: GamerTheme.borderDark),
                                  ),
                                  padding: const EdgeInsets.all(10),
                                ),
                                icon: const Icon(Icons.share_rounded, size: 18, color: GamerTheme.accentOrange),
                                onPressed: () => _shareProfile(user),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Multi-Game Rank Verification Section
                        _buildGameRanksSection(user, isOwnProfile),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // Facebook-Style Tabs: Posts | About
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      indicatorColor: GamerTheme.accentBlue,
                      indicatorWeight: 3,
                      labelColor: GamerTheme.accentBlue,
                      unselectedLabelColor: GamerTheme.textMuted,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      tabs: const [
                        Tab(icon: Icon(Icons.grid_view_rounded, size: 18), text: 'Posts'),
                        Tab(icon: Icon(Icons.info_outline_rounded, size: 18), text: 'About'),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Posts Tab (Shows merged text posts & Cloudinary video clips)
                PostsTab(
                  user: user,
                  isOwnProfile: isOwnProfile,
                ),

                // Tab 2: About Tab (Facebook-style info card)
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAboutCard(
                        icon: Icons.badge_outlined,
                        title: 'Official Gamer Handle',
                        value: '@${user.username}',
                        color: GamerTheme.accentOrange,
                      ),
                      const SizedBox(height: 12),
                      _buildAboutCard(
                        icon: Icons.sports_esports_outlined,
                        title: 'Main Game',
                        value: '$gameEmoji ${user.favoriteGame}',
                        color: gameColor,
                      ),
                      const SizedBox(height: 12),
                      _buildAboutCard(
                        icon: Icons.military_tech_outlined,
                        title: 'Competitive Tier',
                        value: user.rank,
                        color: GamerTheme.flameOrange,
                      ),
                      const SizedBox(height: 12),
                      _buildAboutCard(
                        icon: Icons.auto_awesome_rounded,
                        title: 'App Rank (Auto)',
                        value: '${user.appRank} (${user.appPoints} pts • Level ${user.level})',
                        color: const Color(0xFF00E5FF),
                      ),
                      const SizedBox(height: 12),
                      _buildAboutCard(
                        icon: Icons.calendar_today_outlined,
                        title: 'Member Since',
                        value: user.createdAt != null
                            ? DateFormat('MMMM yyyy').format(user.createdAt!)
                            : '2026',
                        color: GamerTheme.accentBlue,
                      ),
                      const SizedBox(height: 24),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => VerificationScreen(user: user)),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: GamerTheme.cardGradient,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: user.isVerifiedBadge
                                    ? Colors.blue
                                    : (user.isPendingVerification ? const Color(0xFFFF8A00) : GamerTheme.borderDark),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: (user.isVerifiedBadge
                                            ? Colors.blue
                                            : (user.isPendingVerification ? const Color(0xFFFF8A00) : GamerTheme.accentBlue))
                                        .withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    user.isVerifiedBadge
                                        ? Icons.verified_rounded
                                        : (user.isPendingVerification ? Icons.hourglass_top_rounded : Icons.verified_user_outlined),
                                    color: user.isVerifiedBadge
                                        ? Colors.blue
                                        : (user.isPendingVerification ? const Color(0xFFFF8A00) : GamerTheme.accentBlue),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            user.isVerifiedBadge
                                                ? 'Official Verified Gamer ID'
                                                : (user.isPendingVerification ? 'Verification Under Review 24h' : 'Blue Tick Verification'),
                                            style: const TextStyle(
                                              color: GamerTheme.textWhite,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          if (user.isVerifiedBadge)
                                            const Icon(Icons.verified, color: Colors.blue, size: 16)
                                          else if (user.isPendingVerification)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFF8A00).withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('24H REVIEW', style: TextStyle(color: Color(0xFFFF8A00), fontSize: 8.5, fontWeight: FontWeight.w900)),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        user.isVerifiedBadge
                                            ? 'Blue Tick active • All 6 BGMI integrity requirements verified.'
                                            : (user.isPendingVerification
                                                ? 'Application submitted • Verifying requirements in 24h.'
                                                : 'View 6 requirements checklist & apply for Blue Tick ✓'),
                                        style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_ios_rounded, color: GamerTheme.textMuted, size: 14),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAboutCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GamerTheme.borderDark),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: GamerTheme.textWhite, fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }

  // ===================== MULTI-GAME RANK VERIFICATION =====================

  static const Map<String, List<String>> _kGameRankOptions = {
    'BGMI': [
      'Crown I',
      'Crown II',
      'Crown III',
      'Crown IV',
      'Crown V',
      'ACE',
      'ACE Master',
      'ACE Dominator',
      'Conqueror',
      'Top 100 Conqueror',
    ],
    'PUBG Mobile': [
      'Crown I',
      'Crown II',
      'Crown III',
      'Crown IV',
      'Crown V',
      'ACE',
      'ACE Master',
      'ACE Dominator',
      'Conqueror',
      'Top 100 Conqueror',
    ],
    'Free Fire': [
      'Diamond V',
      'Heroic',
      'Elite Heroic',
      'Master',
      'Elite Master',
      'Grandmaster',
      'Top 300 Grandmaster',
      'Top 100 Grandmaster',
      'Regional Top',
      'World Top',
    ],
    'COD Mobile': [
      'Pro III',
      'Pro IV',
      'Pro V',
      'Master I',
      'Master II',
      'Master III',
      'Master IV',
      'Master V',
      'Legendary',
      'Top 5000 Legendary',
    ],
    'Valorant': [
      'Diamond 3',
      'Ascendant 1',
      'Ascendant 2',
      'Ascendant 3',
      'Immortal 1',
      'Immortal 2',
      'Immortal 3',
      'Radiant',
      'Top 500 Radiant',
      'Regional Radiant',
    ],
  };

  IconData _getGameIcon(String gameName) {
    switch (gameName) {
      case 'BGMI':
      case 'PUBG Mobile':
        return Icons.sports_esports_rounded;
      case 'Free Fire':
        return Icons.local_fire_department_rounded;
      case 'COD Mobile':
        return Icons.military_tech_rounded;
      case 'Valorant':
        return Icons.change_history_rounded;
      default:
        return Icons.videogame_asset_rounded;
    }
  }

  Color _getGameAccentColor(String gameName) {
    switch (gameName) {
      case 'BGMI':
        return const Color(0xFFFF8A00);
      case 'PUBG Mobile':
        return const Color(0xFFFFB800);
      case 'Free Fire':
        return const Color(0xFFFF334B);
      case 'COD Mobile':
        return const Color(0xFF00FF88);
      case 'Valorant':
        return const Color(0xFFFF4655);
      default:
        return const Color(0xFF00E5FF);
    }
  }

  Widget _buildGameRanksSection(GamerUser user, bool isOwnProfile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.military_tech_rounded, size: 16, color: GamerTheme.flameOrange),
            const SizedBox(width: 6),
            const Text(
              'VERIFIED GAME RANKS',
              style: TextStyle(
                color: GamerTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            if (isOwnProfile)
              OutlinedButton.icon(
                onPressed: () => _showAddVerifyGameRankSheet(user),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
                  backgroundColor: const Color(0xFF00E5FF).withOpacity(0.08),
                  foregroundColor: const Color(0xFF00E5FF),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add_moderator_rounded, size: 14),
                label: const Text(
                  'Add / Verify Game Rank (Optional - For Pro Players Only)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (user.games.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: GamerTheme.cardDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: GamerTheme.borderDark),
            ),
            child: Column(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF8B949E), size: 30),
                const SizedBox(height: 8),
                const Text(
                  'No verified game ranks yet (Optional)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  isOwnProfile
                      ? 'Submit your in-game UID and rank screenshot proof to get official verified status! (100% Optional for Pro Players)'
                      : 'This player has not verified any competitive game ranks yet.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11.5),
                ),
                if (isOwnProfile) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showAddVerifyGameRankSheet(user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: const Color(0xFF0B0F14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                    label: const Text(
                      'Add / Verify Game Rank (Optional - For Pro Players Only)',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ] else ...[
          Column(
            children: user.games.map((game) {
              final isApproved = game.status == 'approved' || game.isVerified;
              final isPending = game.status == 'pending';
              final isRejected = game.status == 'rejected';
              final gameColor = _getGameAccentColor(game.gameName);

              final Color statusBadgeColor = isApproved
                  ? const Color(0xFF00FF88)
                  : (isPending ? const Color(0xFFFF8A00) : const Color(0xFFFF4655));

              final String statusText = isApproved
                  ? 'Verified ✓'
                  : (isPending ? 'Pending' : 'Rejected');

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GamerTheme.cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isApproved
                        ? const Color(0xFF00FF88).withOpacity(0.4)
                        : (isPending ? const Color(0xFFFF8A00).withOpacity(0.3) : GamerTheme.borderDark),
                  ),
                ),
                child: Row(
                  children: [
                    // Game Logo / Icon
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: gameColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: gameColor.withOpacity(0.4)),
                      ),
                      child: Icon(_getGameIcon(game.gameName), color: gameColor, size: 20),
                    ),
                    const SizedBox(width: 12),

                    // Game Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                game.gameName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusBadgeColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: statusBadgeColor.withOpacity(0.4)),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusBadgeColor,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'UID: ${game.gameId}',
                            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                isApproved && game.verifiedRank.isNotEmpty
                                    ? 'Verified Rank: ${game.verifiedRank}'
                                    : 'Claimed Rank: ${game.claimedRank}',
                                style: TextStyle(
                                  color: isApproved ? const Color(0xFF00FF88) : const Color(0xFFFF8A00),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (isApproved) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF00FF88), size: 13),
                              ],
                            ],
                          ),
                          if (isRejected && game.rejectReason != null && game.rejectReason!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Reason: ${game.rejectReason}',
                              style: const TextStyle(color: Color(0xFFFF4655), fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Proof thumbnail button if screenshot exists
                    if (game.screenshotUrl.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'View Screenshot Proof',
                        icon: const Icon(Icons.photo_library_outlined, size: 20, color: Color(0xFF00E5FF)),
                        onPressed: () => _showScreenshotProofDialog(
                          imageUrl: game.screenshotUrl,
                          title: '${game.gameName} Rank Proof • UID: ${game.gameId}',
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  void _showScreenshotProofDialog({required String imageUrl, required String title}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF10141D),
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: imageUrl.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Padding(
                            padding: EdgeInsets.all(48),
                            child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                          ),
                          errorWidget: (_, __, ___) => const Padding(
                            padding: EdgeInsets.all(48),
                            child: Icon(Icons.broken_image_rounded, color: Colors.red, size: 48),
                          ),
                        )
                      : Image.file(
                          File(imageUrl),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Padding(
                            padding: EdgeInsets.all(48),
                            child: Icon(Icons.broken_image_rounded, color: Colors.red, size: 48),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddVerifyGameRankSheet(GamerUser user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AddVerifyGameRankSheet(user: user),
    );
  }
}

class AddVerifyGameRankSheet extends StatefulWidget {
  final GamerUser user;

  const AddVerifyGameRankSheet({super.key, required this.user});

  @override
  State<AddVerifyGameRankSheet> createState() => _AddVerifyGameRankSheetState();
}

class _AddVerifyGameRankSheetState extends State<AddVerifyGameRankSheet> {
  final _formKey = GlobalKey<FormState>();
  String _selectedGame = 'BGMI';
  late String _selectedRank;
  late TextEditingController _gameIdController;
  File? _pickedScreenshot;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedRank = _GamerProfileScreenState._kGameRankOptions['BGMI']!.first;
    _gameIdController = TextEditingController(text: widget.user.gameId);
  }

  @override
  void dispose() {
    _gameIdController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _pickedScreenshot = File(picked.path);
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not select image: $e';
      });
    }
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickedScreenshot == null) {
      setState(() {
        _errorMessage = 'Rank screenshot proof is required. Please upload your in-game profile screenshot.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final cleanGameName = _selectedGame.replaceAll(RegExp(r'\s+'), '_').toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${cleanGameName}_$timestamp.jpg';

      String downloadUrl = '';
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('rank_verifications')
            .child(widget.user.uid)
            .child(fileName);

        final uploadTask = await storageRef.putFile(_pickedScreenshot!);
        downloadUrl = await uploadTask.ref.getDownloadURL();
      } catch (storageError) {
        debugPrint('FirebaseStorage upload note: $storageError. Using local file path fallback.');
        downloadUrl = _pickedScreenshot!.path;
      }

      // Update user doc games array
      final docRef = FirebaseFirestore.instance.collection('users').doc(widget.user.uid);
      final docSnap = await docRef.get();
      final currentData = docSnap.data() ?? {};
      final rawGames = currentData['games'] as List? ?? [];
      final List<Map<String, dynamic>> gamesList = [];
      bool replaced = false;
      final entryId = 'game_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

      for (final g in rawGames) {
        if (g is Map) {
          final map = Map<String, dynamic>.from(g);
          if (map['gameName'] == _selectedGame) {
            gamesList.add({
              'id': map['id'] ?? entryId,
              'gameName': _selectedGame,
              'gameId': _gameIdController.text.trim(),
              'claimedRank': _selectedRank,
              'verifiedRank': '',
              'isVerified': false,
              'screenshotUrl': downloadUrl,
              'status': 'pending',
              'submittedAt': Timestamp.now(),
              'ownerUid': widget.user.uid,
            });
            replaced = true;
          } else {
            gamesList.add(map);
          }
        }
      }

      if (!replaced) {
        gamesList.add({
          'id': entryId,
          'gameName': _selectedGame,
          'gameId': _gameIdController.text.trim(),
          'claimedRank': _selectedRank,
          'verifiedRank': '',
          'isVerified': false,
          'screenshotUrl': downloadUrl,
          'status': 'pending',
          'submittedAt': Timestamp.now(),
          'ownerUid': widget.user.uid,
        });
      }

      await docRef.set({
        'games': gamesList,
        if (widget.user.gameId.isEmpty) 'gameId': _gameIdController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Submitted $_selectedGame rank verification ($_selectedRank)! Pending admin review.',
            ),
            backgroundColor: const Color(0xFF00FF88),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Error submitting verification: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final availableRanks = _GamerProfileScreenState._kGameRankOptions[_selectedGame] ?? ['Crown I'];

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF10141D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF1F2B3E), width: 1.5)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E384D),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: Color(0xFF00E5FF), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add / Verify Game Rank (Optional)',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        Text(
                          'Upload screenshot proof to verify in-game UID & Rank (For Pro Players Only)',
                          style: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // a) Select Game Dropdown
              const Text(
                '1. Select Game',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedGame,
                dropdownColor: const Color(0xFF161B26),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF161B26),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF1F2B3E)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF1F2B3E)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                  ),
                ),
                items: ['BGMI', 'PUBG Mobile', 'Free Fire', 'COD Mobile', 'Valorant'].map((g) {
                  return DropdownMenuItem<String>(
                    value: g,
                    child: Row(
                      children: [
                        const Icon(Icons.sports_esports_rounded, size: 16, color: Color(0xFF00E5FF)),
                        const SizedBox(width: 8),
                        Text(g),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedGame = val;
                      _selectedRank = _GamerProfileScreenState._kGameRankOptions[val]!.first;
                    });
                  }
                },
              ),

              const SizedBox(height: 14),

              // b) Enter Game UID/ID
              const Text(
                '2. In-Game UID / Player ID',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _gameIdController,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  hintText: 'Enter your exact in-game UID (e.g. 5123456789)',
                  hintStyle: const TextStyle(color: Color(0xFF6E7681), fontSize: 13),
                  prefixIcon: const Icon(Icons.tag_rounded, color: Color(0xFF00E5FF), size: 18),
                  filled: true,
                  fillColor: const Color(0xFF161B26),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF1F2B3E)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF1F2B3E)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your in-game UID';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // c) Select Claimed Rank Dropdown
              const Text(
                '3. Claimed In-Game Rank',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: availableRanks.contains(_selectedRank) ? _selectedRank : availableRanks.first,
                dropdownColor: const Color(0xFF161B26),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF161B26),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF1F2B3E)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF1F2B3E)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                  ),
                ),
                items: availableRanks.map((r) {
                  return DropdownMenuItem<String>(
                    value: r,
                    child: Row(
                      children: [
                        const Icon(Icons.military_tech_rounded, size: 16, color: Color(0xFFFF8A00)),
                        const SizedBox(width: 8),
                        Text(r),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedRank = val);
                  }
                },
              ),

              const SizedBox(height: 16),

              // d) Upload Screenshot (required)
              Row(
                children: [
                  const Text(
                    '4. Upload Screenshot Proof',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4655).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'REQUIRED',
                      style: TextStyle(color: Color(0xFFFF4655), fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Must show your Game ID + Rank clearly on screen',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 11.5),
              ),
              const SizedBox(height: 8),

              // Screenshot Picker Box
              InkWell(
                onTap: _pickScreenshot,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _pickedScreenshot != null ? const Color(0xFF00FF88) : const Color(0xFF2E384D),
                      width: 1.5,
                    ),
                  ),
                  child: _pickedScreenshot != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(_pickedScreenshot!, fit: BoxFit.cover),
                              Container(
                                color: Colors.black.withOpacity(0.4),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10141D),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF00FF88)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: Color(0xFF00FF88), size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Change Photo',
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF00E5FF), size: 36),
                            SizedBox(height: 6),
                            Text(
                              'Tap to upload rank screenshot proof',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'JPG, PNG supported',
                              style: TextStyle(color: Color(0xFF6E7681), fontSize: 11),
                            ),
                          ],
                        ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4655).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFF4655).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFFF4655), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFFFF4655), fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // e) Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: const Color(0xFF0B0F14),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Color(0xFF0B0F14), strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _isSubmitting ? 'Submitting Verification...' : 'Submit Rank Verification',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
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


class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: GamerTheme.bgDark,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
