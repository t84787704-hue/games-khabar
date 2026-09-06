import 'package:flutter/material.dart';
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
import 'create_gamer_id_screen.dart';
import 'followers_following_screen.dart';
import 'gamer_auth_screen.dart';
import 'saved_news_tab_screen.dart';

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
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  backgroundColor: GamerTheme.cardDark,
                  title: Text(
                    isOwnProfile ? 'My Gamer ID' : '@${user.username}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  actions: [
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
                        // Facebook-Style Cover Art Placeholder / Gradient
                        Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF0F2027),
                                const Color(0xFF203A43),
                                gameColor.withOpacity(0.4),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                right: -20,
                                top: -20,
                                child: Icon(
                                  Icons.sports_esports_rounded,
                                  size: 160,
                                  color: Colors.white.withOpacity(0.06),
                                ),
                              ),
                              Positioned(
                                left: 16,
                                top: 50,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.4),
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
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Facebook-Style Circular Profile Photo
                        Positioned(
                          top: 105,
                          left: 20,
                          child: GamerAvatar(
                            photoUrl: user.photoUrl,
                            displayName: user.displayName,
                            radius: 46,
                            hasGlow: true,
                            borderColor: gameColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // User Info & Badges Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display Name + Rank Badge + Verified Badge
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
                            RankBadgeWidget(
                              badge: user.getRankBadge(),
                              size: 16,
                              showLabel: true,
                            ),
                            if (user.isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, color: Colors.blue, size: 20),
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

                        // Favorite Game Badge & Rank Chip
                        Row(
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
                            const SizedBox(width: 8),

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
                          ],
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
                              _buildStatColumn('${user.postsCount}', 'Posts', () {
                                _tabController.animateTo(0);
                              }),
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
                // Tab 1: Posts Tab
                StreamBuilder<List<GamerPost>>(
                  stream: _socialService.getUserPostsStream(user.uid),
                  builder: (context, postSnap) {
                    if (postSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: GamerTheme.accentBlue));
                    }

                    final posts = postSnap.data ?? [];
                    if (posts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.post_add_rounded, color: GamerTheme.textMuted, size: 48),
                            const SizedBox(height: 10),
                            Text(
                              isOwnProfile
                                  ? 'You haven\'t posted anything yet.'
                                  : '@${user.username} hasn\'t posted yet.',
                              style: const TextStyle(color: GamerTheme.textGray, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Share gameplay updates, squad room codes & tips!',
                              style: TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: posts.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, index) {
                        return PostCard(post: posts[index]);
                      },
                    );
                  },
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
                        icon: Icons.calendar_today_outlined,
                        title: 'Member Since',
                        value: user.createdAt != null
                            ? DateFormat('MMMM yyyy').format(user.createdAt!)
                            : '2026',
                        color: GamerTheme.accentBlue,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: GamerTheme.cardGradient,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: GamerTheme.borderDark),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: GamerTheme.accentBlue.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.verified_user_outlined, color: GamerTheme.accentBlue, size: 24),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Verified Gamer ID',
                                    style: TextStyle(
                                      color: GamerTheme.textWhite,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'This Gamer ID is uniquely registered on the Firebase network.',
                                    style: TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
