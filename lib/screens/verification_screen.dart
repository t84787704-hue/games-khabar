// ===============================================================================
// VERIFICATION SCREEN — Free Application & Instant VIP Blue Tick (2,000 Coins)
// -------------------------------------------------------------------------------
// File: lib/screens/verification_screen.dart
// ===============================================================================

import 'package:flutter/material.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_user_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/verification_service.dart';
import '../services/coin_wallet_service.dart';
import '../services/supabase_service.dart';
import 'create_gamer_id_screen.dart';
import 'create_post_screen.dart';

class VerificationScreen extends StatefulWidget {
  final GamerUser? user;

  const VerificationScreen({super.key, this.user});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final GamerAuthService _authService = GamerAuthService();
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isPurchasingVip = false;
  VerificationStats? _liveStats;
  GamerUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user ?? _authService.currentGamer;
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final uid = _currentUser?.uid ?? _authService.currentUid ?? '';
      if (uid.isNotEmpty) {
        final stats = await VerificationService.fetchLiveStats(uid);
        final freshestUser = await _authService.fetchUserProfile(uid);
        if (mounted) {
          setState(() {
            _liveStats = stats;
            if (freshestUser != null) {
              _currentUser = freshestUser;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error refreshing verification data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// ⚡ INSTANT VIP BLUE TICK (2,000 Coins Purchase Logic)
  Future<void> _handleInstantVipBuy(GamerUser user) async {
    final wallet = await CoinWalletService().getOrCreateWallet(user.uid);

    if (wallet.coins < 2000) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: GamerTheme.cardElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB800), size: 24),
              SizedBox(width: 8),
              Text('Coins Kam Hain!', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Instant VIP Blue Tick hasil karne ke liye 2,000 coins darkaar hain.\n\nAapke wallet mein is waqt ${wallet.coins} coins hain. Ads dekh kar ya Top-up kar ke balance poora karein.',
            style: const TextStyle(color: GamerTheme.textGray, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Theek Hai', style: TextStyle(color: GamerTheme.accentBlue, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GamerTheme.cardElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: Colors.blue, size: 24),
            SizedBox(width: 8),
            Text('VIP Blue Tick Unlock?', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Kya aap 2,000 Coins ada karke foran official Blue Tick hasil karna chahte hain? Koi task poora karne ki zaroorat nahi hogi.',
          style: TextStyle(color: GamerTheme.textGray, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: GamerTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Haan, 2,000 Coins Pay Karein', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isPurchasingVip = true);

    try {
      // 1. Deduct 2,000 coins via CoinWalletService
      await CoinWalletService.updateCoins(
        userId: user.uid,
        amount: -2000,
        type: 'store_purchase',
        title: 'VIP Blue Tick Verification ✨',
        description: 'Instant Blue Tick unlocked via 2,000 Coins',
      );

      // 2. Update user profile to Verified in Supabase
      await SupabaseService.client.from('users').update({
        'is_verified': true,
        'has_blue_tick': true,
        'verification_status': 'verified',
        'updated_at': DateTime.now().toIso8601String(),
      }).or('id.eq.${user.uid},uid.eq.${user.uid}');

      // 3. Update in-memory user
      await _authService.refreshCurrentGamer();
      final freshest = await _authService.fetchUserProfile(user.uid);

      if (mounted) {
        setState(() {
          _currentUser = freshest ?? user.copyWith(
            verificationStatus: 'verified',
            isVerified: true,
          );
        });
        _showVerifiedCelebrationDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GamerTheme.redAccent,
            content: Text('Purchase error: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPurchasingVip = false);
    }
  }

  Future<void> _handleApply(GamerUser user) async {
    final canApply = VerificationService.canApplyForVerification(
      user,
      clipsCount: _liveStats?.clipsCount,
      squadRoomsCount: _liveStats?.squadRoomsCount,
      likesReceived: _liveStats?.likesReceived,
      reportsCount: _liveStats?.reportsCount,
      accountAgeDays: _liveStats?.accountAgeDays,
    );

    if (!canApply) {
      final reqs = VerificationService.getRequirements(
        user,
        clipsCount: _liveStats?.clipsCount,
        squadRoomsCount: _liveStats?.squadRoomsCount,
        likesReceived: _liveStats?.likesReceived,
        reportsCount: _liveStats?.reportsCount,
        accountAgeDays: _liveStats?.accountAgeDays,
      );
      final unmet = reqs.where((r) => !r.isMet).toList();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GamerTheme.redAccent,
          content: Row(
            children: [
              const Icon(Icons.cancel_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cannot apply: ${unmet.length} requirement(s) missing.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await VerificationService.setPendingUnderReview(user.uid);
      if (mounted) {
        setState(() {
          _currentUser = user.copyWith(
            verificationStatus: 'pending',
            isVerified: false,
          );
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFFF8A00),
          content: Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Application Submitted! Status: Under Review 24h.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 900));
      final result = await VerificationService.applyForVerification(user);

      if (!mounted) return;
      if (result.success && result.isVerified) {
        final verifiedUser = await _authService.fetchUserProfile(user.uid);
        setState(() {
          _currentUser = verifiedUser ?? user.copyWith(
            verificationStatus: 'verified',
            isVerified: true,
          );
        });
        _showVerifiedCelebrationDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GamerTheme.redAccent,
            content: Text(result.message),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GamerTheme.redAccent,
          content: Text('Submission error: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showVerifiedCelebrationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GamerTheme.cardElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: GamerTheme.accentBlue, width: 2),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.18),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.verified_rounded, color: Colors.blue, size: 64),
            ),
            const SizedBox(height: 16),
            const Text(
              'Official Blue Tick Verified!',
              style: TextStyle(
                color: GamerTheme.textWhite,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Mubarak ho! Aapka official Blue Tick ✓ live ho chuka hai. Yeh badge aapke profile aur tamam posts par show hoga.',
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
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'AWESOME! LET\'S FLEX 🎮',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLinkGameUidDialog(GamerUser user) {
    String selectedGame = user.selectedGame.isNotEmpty
        ? user.selectedGame
        : (user.favoriteGame.isNotEmpty ? user.favoriteGame : 'BGMI');
    final supportedGames = [
      'BGMI',
      'PUBG Mobile',
      'Free Fire',
      'COD Mobile',
      'Valorant',
      'Other',
    ];
    if (!supportedGames.contains(selectedGame)) {
      selectedGame = 'Other';
    }
    final controller = TextEditingController(text: user.gameId);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: GamerTheme.cardElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.sports_esports_rounded, color: GamerTheme.accentBlue, size: 22),
              SizedBox(width: 8),
              Text('Link Game UID', style: TextStyle(color: GamerTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Requirement 1: Select your game and enter your in-game Character ID / UID:',
                style: TextStyle(color: GamerTheme.textGray, fontSize: 12),
              ),
              const SizedBox(height: 14),
              const Text('SELECT GAME', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
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
                    value: selectedGame,
                    isExpanded: true,
                    dropdownColor: GamerTheme.cardElevated,
                    items: supportedGames.map((g) {
                      return DropdownMenuItem<String>(
                        value: g,
                        child: Text(g, style: const TextStyle(color: GamerTheme.textWhite)),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setDlgState(() => selectedGame = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('GAME CHARACTER UID', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'e.g. 5129384729 or Player#1234',
                  hintStyle: const TextStyle(color: GamerTheme.textMuted),
                  filled: true,
                  fillColor: GamerTheme.cardDark,
                  prefixIcon: const Icon(Icons.tag_rounded, color: GamerTheme.accentBlue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: GamerTheme.borderDark),
                  ),
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
                final val = controller.text.trim();
                if (val.isNotEmpty) {
                  Navigator.pop(ctx);
                  await VerificationService.linkGameId(
                    userId: user.uid,
                    gameId: val,
                    gameName: selectedGame,
                  );
                  _refreshData();
                }
              },
              child: const Text('Save & Link', style: TextStyle(color: GamerTheme.bgDark, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickRankKdDialog(GamerUser user) {
    String selectedGame = user.selectedGame.isNotEmpty
        ? user.selectedGame
        : (user.favoriteGame.isNotEmpty ? user.favoriteGame : 'BGMI');
    String selectedRank = user.rank.isEmpty ? 'Ace' : user.rank;
    final kdController = TextEditingController(text: user.kdRatio > 0 ? user.kdRatio.toString() : '3.5');

    final ranksList = [
      'Bronze',
      'Silver',
      'Gold',
      'Platinum',
      'Diamond',
      'Crown',
      'Ace',
      'Ace Master',
      'Ace Dominator',
      'Conqueror',
      'Heroic',
      'Grandmaster',
      'Legendary',
      'Immortal',
      'Radiant',
      'Champion',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: GamerTheme.cardElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.military_tech_rounded, color: GamerTheme.flameOrange, size: 22),
              SizedBox(width: 8),
              Text('Update Rank & Stats', style: TextStyle(color: GamerTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select your competitive rank and stats in $selectedGame:',
                  style: const TextStyle(color: GamerTheme.textGray, fontSize: 12),
                ),
                const SizedBox(height: 16),
                const Text('GAME RANK', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
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
                      value: ranksList.contains(selectedRank) ? selectedRank : ranksList.first,
                      isExpanded: true,
                      dropdownColor: GamerTheme.cardElevated,
                      items: ranksList.map((r) {
                        final isEligible = VerificationService.isRankEligible(r);
                        return DropdownMenuItem<String>(
                          value: r,
                          child: Row(
                            children: [
                              Icon(
                                isEligible ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                size: 16,
                                color: isEligible ? GamerTheme.neonGreen : GamerTheme.redAccent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                r,
                                style: TextStyle(
                                  color: isEligible ? GamerTheme.textWhite : GamerTheme.textMuted,
                                  fontWeight: isEligible ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setDlgState(() => selectedRank = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('GAME STATS / K/D (Optional)', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: kdController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'e.g. 3.50 (Optional)',
                    hintStyle: const TextStyle(color: GamerTheme.textMuted),
                    filled: true,
                    fillColor: GamerTheme.cardDark,
                    prefixIcon: const Icon(Icons.speed_rounded, color: GamerTheme.flameOrange),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: GamerTheme.borderDark),
                    ),
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
              style: ElevatedButton.styleFrom(backgroundColor: GamerTheme.flameOrange),
              onPressed: () async {
                final double? kd = double.tryParse(kdController.text.trim());
                Navigator.pop(ctx);
                await _authService.updateProfile(
                  rank: selectedRank,
                  kdRatio: kd,
                );
                _refreshData();
              },
              child: const Text('Update Rank', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GamerUser?>(
      stream: _authService.userProfileStream(_currentUser?.uid ?? _authService.currentUid ?? ''),
      builder: (context, snapshot) {
        final user = snapshot.data ?? _currentUser;

        return Scaffold(
          backgroundColor: GamerTheme.bgDark,
          appBar: AppBar(
            backgroundColor: GamerTheme.cardDark,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: GamerTheme.textWhite, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Row(
              children: [
                Icon(Icons.verified_rounded, color: Colors.blue, size: 22),
                SizedBox(width: 8),
                Text(
                  'Blue Tick Verification',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: GamerTheme.textWhite),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: GamerTheme.accentBlue),
                tooltip: 'Refresh Requirements',
                onPressed: _refreshData,
              ),
            ],
          ),
          body: user == null
              ? const Center(child: CircularProgressIndicator(color: GamerTheme.accentBlue))
              : _isLoading
                  ? const Center(child: CircularProgressIndicator(color: GamerTheme.accentBlue))
                  : _buildBody(user),
        );
      },
    );
  }

  Widget _buildBody(GamerUser user) {
    final reqs = VerificationService.getRequirements(
      user,
      clipsCount: _liveStats?.clipsCount,
      squadRoomsCount: _liveStats?.squadRoomsCount,
      likesReceived: _liveStats?.likesReceived,
      reportsCount: _liveStats?.reportsCount,
      accountAgeDays: _liveStats?.accountAgeDays,
    );

    final int metCount = reqs.where((r) => r.isMet).length;
    final bool allMet = metCount == reqs.length;
    final bool isVerified = user.isVerified || user.verificationStatus == 'verified';
    final bool isPending = user.verificationStatus == 'pending' && !isVerified;

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: GamerTheme.accentBlue,
      backgroundColor: GamerTheme.cardDark,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header Banner
            _buildStatusHeaderCard(user, isVerified: isVerified, isPending: isPending, metCount: metCount, totalCount: reqs.length),
            const SizedBox(height: 16),

            // ⚡ INSTANT VIP BLUE TICK CARD (2,000 Coins)
            if (!isVerified) ...[
              _buildInstantVipBuyCard(user),
              const SizedBox(height: 20),
            ],

            // Requirements Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'MANDATORY REQUIREMENTS',
                  style: TextStyle(
                    color: GamerTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: allMet ? GamerTheme.neonGreen.withOpacity(0.15) : GamerTheme.cardElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: allMet ? GamerTheme.neonGreen : GamerTheme.borderDark),
                  ),
                  child: Text(
                    '$metCount / ${reqs.length} Met',
                    style: TextStyle(
                      color: allMet ? GamerTheme.neonGreen : GamerTheme.textGray,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Requirements Cards
            ...reqs.map((item) => _buildRequirementCard(item, user)),

            const SizedBox(height: 24),

            // Bottom Action
            _buildBottomAction(user, allMet: allMet, isVerified: isVerified, isPending: isPending),

            const SizedBox(height: 16),

            // Quick Shortcuts
            if (!isVerified) _buildQuickActionShortcuts(user),
          ],
        ),
      ),
    );
  }

  /// ⚡ VIP Banner Widget
  Widget _buildInstantVipBuyCard(GamerUser user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.flash_on_rounded, color: Colors.blue, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INSTANT VIP BLUE TICK ⚡',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Sharaait aur intezar ke baghair foran verify hon',
                      style: TextStyle(color: GamerTheme.textGray, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Tasks poore nahi karna chahte? Aap direct 2,000 Coins de kar apni profile par official Blue Tick live kar sakte hain!',
            style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
              icon: _isPurchasingVip
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 18),
              label: Text(
                _isPurchasingVip ? 'Processing...' : 'Unlock Instantly (2,000 Coins)',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
              onPressed: _isPurchasingVip ? null : () => _handleInstantVipBuy(user),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeaderCard(
    GamerUser user, {
    required bool isVerified,
    required bool isPending,
    required int metCount,
    required int totalCount,
  }) {
    if (user.isOwnerUser) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2A1C0A), Color(0xFF4A3410), Color(0xFF1B1204)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFD700), width: 2),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 40),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue, width: 1.5),
                  ),
                  child: const Icon(Icons.verified_rounded,
