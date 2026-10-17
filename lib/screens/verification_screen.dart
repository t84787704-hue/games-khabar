// ===============================================================================
// VERIFICATION SCREEN — Full Adaptive Day & Night Mode + Multi-Language Support
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
import '../services/language_service.dart';
import '../services/theme_service.dart';
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
            if (freshestUser != null) _currentUser = freshestUser;
          });
        }
      }
    } catch (e) {
      debugPrint('Error refreshing verification data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ⚡ INSTANT VIP BLUE TICK (Theme + Language Adaptive Dialogs)
  Future<void> _handleInstantVipBuy(GamerUser user) async {
    final wallet = await CoinWalletService().getOrCreateWallet(user.uid);

    if (wallet.coins < 2000) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ThemeService.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB800), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  LanguageService.isUrdu
                      ? 'کوائنز کم ہیں!'
                      : (LanguageService.isHindi ? 'कॉइन्स कम हैं!' : 'Insufficient Coins!'),
                  style: TextStyle(color: ThemeService.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            LanguageService.isUrdu
                ? 'وی آئی پی بلیو ٹک کے لیے 2,000 کوائنز درکار ہیں۔ آپ کے والٹ میں اس وقت ${wallet.coins} کوائنز ہیں۔'
                : (LanguageService.isHindi
                    ? 'वीआईपी ब्लू टिक के लिए 2,000 कॉइन्स चाहिए। आपके वॉलेट में अभी ${wallet.coins} कॉइन्स हैं।'
                    : 'Instant VIP Blue Tick requires 2,000 coins. You currently have ${wallet.coins} coins.'),
            style: TextStyle(color: ThemeService.textSecondary, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                LanguageService.isUrdu ? 'ٹھیک ہے' : (LanguageService.isHindi ? 'ठीक है' : 'OK'),
                style: const TextStyle(color: Color(0xFF1877F2), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.verified_rounded, color: Color(0xFF1877F2), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                LanguageService.isUrdu
                    ? 'وی آئی پی بلیو ٹک حاصل کریں؟'
                    : (LanguageService.isHindi ? 'वीआईपी ब्लू टिक अनलॉक?' : 'Unlock VIP Blue Tick?'),
                style: TextStyle(color: ThemeService.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          LanguageService.isUrdu
              ? 'کیا آپ 2,000 کوائنز ادا کر کے فوراً بلیو ٹک حاصل کرنا چاہتے ہیں؟ کسی بھی ٹاسک کی ضرورت نہیں ہوگی۔'
              : (LanguageService.isHindi
                  ? 'क्या आप 2,000 कॉइन्स देकर तुरंत ब्लू टिक अनलॉक करना चाहते हैं?'
                  : 'Do you want to unlock official Blue Tick instantly for 2,000 coins? No tasks required.'),
          style: TextStyle(color: ThemeService.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              LanguageService.isUrdu ? 'منسوخ' : (LanguageService.isHindi ? 'रद्द करें' : 'Cancel'),
              style: TextStyle(color: ThemeService.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1877F2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              LanguageService.isUrdu ? '2,000 کوائنز پے کریں' : (LanguageService.isHindi ? '2,000 कॉइन्स दें' : 'Pay 2,000 Coins'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isPurchasingVip = true);

    try {
      await CoinWalletService.updateCoins(
        userId: user.uid,
        amount: -2000,
        type: 'store_purchase',
        title: 'VIP Blue Tick Verification ✨',
        description: 'Instant Blue Tick unlocked via 2,000 Coins',
      );

      await SupabaseService.client.from('users').update({
        'is_verified': true,
        'has_blue_tick': true,
        'verification_status': 'verified',
        'updated_at': DateTime.now().toIso8601String(),
      }).or('id.eq.${user.uid},uid.eq.${user.uid}');

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
          SnackBar(backgroundColor: const Color(0xFFFF4655), content: Text('Error: $e')),
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
          backgroundColor: const Color(0xFFFF4655),
          content: Text(
            LanguageService.isUrdu
                ? 'درخواست نہیں بھیجی جا سکتی: ${unmet.length} شرائط باقی ہیں۔'
                : 'Cannot apply: ${unmet.length} requirement(s) missing.',
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
          _currentUser = user.copyWith(verificationStatus: 'pending', isVerified: false);
        });
      }

      await Future.delayed(const Duration(milliseconds: 800));
      final result = await VerificationService.applyForVerification(user);

      if (!mounted) return;
      if (result.success && result.isVerified) {
        final verifiedUser = await _authService.fetchUserProfile(user.uid);
        setState(() {
          _currentUser = verifiedUser ?? user.copyWith(verificationStatus: 'verified', isVerified: true);
        });
        _showVerifiedCelebrationDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFFF4655), content: Text(result.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFFF4655), content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showVerifiedCelebrationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1877F2), width: 2),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_rounded, color: Color(0xFF1877F2), size: 64),
            const SizedBox(height: 16),
            Text(
              LanguageService.isUrdu ? 'مبارک ہو! بلیو ٹک تصدیق شدہ' : 'Official Blue Tick Verified!',
              style: TextStyle(color: ThemeService.textPrimary, fontSize: 20, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              LanguageService.isUrdu
                  ? 'آپ کا بلیو ٹک فعال ہو چکا ہے۔ یہ بیج آپ کی پروفائل اور تمام پوسٹس پر نظر آئے گا۔'
                  : 'Your official Blue Tick is now live across your profile and posts!',
              style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  LanguageService.isUrdu ? 'بہترین! آگے بڑھیں' : 'LET\'S FLEX 🎮',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLinkGameUidDialog(GamerUser user) {
    String selectedGame = user.selectedGame.isNotEmpty ? user.selectedGame : (user.favoriteGame.isNotEmpty ? user.favoriteGame : 'BGMI');
    final supportedGames = ['BGMI', 'PUBG Mobile', 'Free Fire', 'COD Mobile', 'Valorant', 'Other'];
    if (!supportedGames.contains(selectedGame)) selectedGame = 'Other';
    final controller = TextEditingController(text: user.gameId);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: ThemeService.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            LanguageService.isUrdu ? 'گیم یو آئی ڈی لنک کریں' : 'Link Game UID',
            style: TextStyle(color: ThemeService.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedGame,
                dropdownColor: ThemeService.card,
                style: TextStyle(color: ThemeService.textPrimary),
                decoration: InputDecoration(
                  labelText: LanguageService.isUrdu ? 'گیم منتخب کریں' : 'Game',
                  labelStyle: TextStyle(color: ThemeService.textSecondary),
                ),
                items: supportedGames.map((g) => DropdownMenuItem(value: g, child: Text(g, style: TextStyle(color: ThemeService.textPrimary)))).toList(),
                onChanged: (v) {
                  if (v != null) setDlgState(() => selectedGame = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: TextStyle(color: ThemeService.textPrimary),
                decoration: InputDecoration(
                  labelText: LanguageService.isUrdu ? 'کریکٹر یو آئی ڈی' : 'Character UID',
                  labelStyle: TextStyle(color: ThemeService.textSecondary),
                  hintText: 'e.g. 5129384729',
                  hintStyle: TextStyle(color: ThemeService.textSecondary.withOpacity(0.5)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                LanguageService.isUrdu ? 'منسوخ' : LanguageService.t('Cancel'),
                style: TextStyle(color: ThemeService.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1877F2)),
              onPressed: () async {
                final val = controller.text.trim();
                if (val.isNotEmpty) {
                  Navigator.pop(ctx);
                  await VerificationService.linkGameId(userId: user.uid, gameId: val, gameName: selectedGame);
                  _refreshData();
                }
              },
              child: Text(
                LanguageService.isUrdu ? 'محفوظ کریں' : 'Save',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickRankKdDialog(GamerUser user) {
    String selectedGame = user.selectedGame.isNotEmpty ? user.selectedGame : (user.favoriteGame.isNotEmpty ? user.favoriteGame : 'BGMI');
    String selectedRank = user.rank.isEmpty ? 'Ace' : user.rank;
    final ranksList = ['Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond', 'Crown', 'Ace', 'Ace Master', 'Ace Dominator', 'Conqueror', 'Heroic', 'Grandmaster', 'Legendary', 'Immortal'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: ThemeService.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            LanguageService.isUrdu ? '$selectedGame میں رینک منتخب کریں' : 'Rank in $selectedGame',
            style: TextStyle(color: ThemeService.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: DropdownButtonFormField<String>(
            value: ranksList.contains(selectedRank) ? selectedRank : ranksList.first,
            dropdownColor: ThemeService.card,
            items: ranksList.map((r) => DropdownMenuItem(value: r, child: Text(r, style: TextStyle(color: ThemeService.textPrimary)))).toList(),
            onChanged: (v) {
              if (v != null) setDlgState(() => selectedRank = v);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                LanguageService.isUrdu ? 'منسوخ' : LanguageService.t('Cancel'),
                style: TextStyle(color: ThemeService.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00)),
              onPressed: () async {
                Navigator.pop(ctx);
                await _authService.updateProfile(rank: selectedRank);
                _refreshData();
              },
              child: Text(
                LanguageService.isUrdu ? 'اپ ڈیٹ کریں' : 'Update',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        return ValueListenableBuilder<String>(
          valueListenable: LanguageService.currentLanguage,
          builder: (context, _, __) {
            return StreamBuilder<GamerUser?>(
              stream: _authService.userProfileStream(_currentUser?.uid ?? _authService.currentUid ?? ''),
              builder: (context, snapshot) {
                final user = snapshot.data ?? _currentUser;

                return Scaffold(
                  backgroundColor: ThemeService.bg,
                  appBar: AppBar(
                    backgroundColor: ThemeService.appBarBg,
                    elevation: ThemeService.isDarkMode ? 0 : 1,
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: ThemeService.textPrimary, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: Color(0xFF1877F2), size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            LanguageService.isUrdu ? 'بلیو ٹک تصدیق' : 'Blue Tick Verification',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: ThemeService.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1877F2)),
                        tooltip: 'Refresh',
                        onPressed: _refreshData,
                      ),
                    ],
                  ),
                  body: user == null
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF1877F2)))
                      : _isLoading
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1877F2)))
                          : _buildBody(user),
                );
              },
            );
          },
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
      color: const Color(0xFF1877F2),
      backgroundColor: ThemeService.card,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeaderCard(user, isVerified: isVerified, isPending: isPending, metCount: metCount, totalCount: reqs.length),
            const SizedBox(height: 16),

            if (!isVerified) ...[
              _buildInstantVipBuyCard(user),
              const SizedBox(height: 20),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  LanguageService.isUrdu ? 'لازمی شرائط' : 'MANDATORY REQUIREMENTS',
                  style: TextStyle(color: ThemeService.textSecondary, fontSize: 12, fontWeight: FontWeight.w900),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: allMet ? const Color(0xFF00FF88).withOpacity(0.15) : ThemeService.cardSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: allMet ? const Color(0xFF00FF88) : ThemeService.border),
                  ),
                  child: Text(
                    '$metCount / ${reqs.length} Met',
                    style: TextStyle(
                      color: allMet ? const Color(0xFF00FF88) : ThemeService.textSecondary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ...reqs.map((item) => _buildRequirementCard(item, user)),

            const SizedBox(height: 24),

            _buildBottomAction(user, allMet: allMet, isVerified: isVerified, isPending: isPending),

            const SizedBox(height: 16),

            if (!isVerified) _buildQuickActionShortcuts(user),
          ],
        ),
      ),
    );
  }

  Widget _buildInstantVipBuyCard(GamerUser user) {
    final isDark = ThemeService.isDarkMode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF172033) : const Color(0xFFE8F4FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1877F2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1877F2).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1877F2).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.flash_on_rounded, color: Color(0xFF1877F2), size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  LanguageService.isUrdu ? 'فوری وی آئی پی بلیو ٹک ⚡' : 'INSTANT VIP BLUE TICK ⚡',
                  style: const TextStyle(color: Color(0xFF1877F2), fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            LanguageService.isUrdu
                ? 'ٹاسک مکمل کرنے کا انتظار نہیں کرنا چاہتے؟ آپ براہ راست 2,000 کوائنز ادا کر کے فوراً بلیو ٹک حاصل کر سکتے ہیں!'
                : 'Skip the wait and requirements! Unlock your official Blue Tick immediately with 2,000 coins.',
            style: TextStyle(color: ThemeService.textPrimary, fontSize: 12.5, height: 1.35),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1877F2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: _isPurchasingVip
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 18),
              label: Text(
                _isPurchasingVip
                    ? 'Processing...'
                    : (LanguageService.isUrdu ? 'فوراً حاصل کریں (2,000 کوائنز)' : 'Unlock Instantly (2,000 Coins)'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: _isPurchasingVip ? null : () => _handleInstantVipBuy(user),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeaderCard(GamerUser user, {required bool isVerified, required bool isPending, required int metCount, required int totalCount}) {
    if (user.isOwnerUser) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: ThemeService.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
        ),
        child: Column(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 40),
            const SizedBox(height: 8),
            const Text('OFFICIAL OWNER & CREATOR 👑', style: TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('LEGEND Badge 👑 • Official Blue Tick Verified ✅', style: TextStyle(color: ThemeService.textPrimary, fontSize: 13)),
          ],
        ),
      );
    }

    if (isVerified) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: ThemeService.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1877F2), width: 1.5),
        ),
        child: Column(
          children: [
            const Icon(Icons.verified_rounded, color: Color(0xFF1877F2), size: 44),
            const SizedBox(height: 8),
            Text(
              LanguageService.isUrdu ? 'تصدیق شدہ بلیو ٹک ✓' : 'Official Blue Tick Verified ✓',
              style: TextStyle(color: ThemeService.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '@${user.username} is an officially verified competitive gamer.',
              style: TextStyle(color: ThemeService.textSecondary, fontSize: 12.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (isPending) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: ThemeService.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF8A00), width: 1.5),
        ),
        child: Column(
          children: [
            const Icon(Icons.hourglass_top_rounded, color: Color(0xFFFF8A00), size: 40),
            const SizedBox(height: 8),
            Text(
              LanguageService.isUrdu ? '24 گھنٹے کے ریویو میں ہے' : 'Under Review 24h',
              style: TextStyle(color: ThemeService.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              LanguageService.isUrdu ? 'آپ کی درخواست 24 گھنٹے کے ریویو میں ہے۔' : 'Your application is currently under 24-hour review.',
              style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeService.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified, color: Color(0xFF1877F2), size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LanguageService.isUrdu ? 'بلیو ٹک حاصل کریں' : 'Get The Official Blue Tick',
                      style: TextStyle(color: ThemeService.textPrimary, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      LanguageService.isUrdu ? 'اپلائی کرنے کے لیے تمام شرائط پوری کریں' : 'User must meet ALL requirements to apply',
                      style: TextStyle(color: ThemeService.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: totalCount > 0 ? metCount / totalCount : 0.0,
              minHeight: 7,
              backgroundColor: ThemeService.cardSecondary,
              valueColor: AlwaysStoppedAnimation<Color>(metCount == totalCount ? const Color(0xFF00FF88) : const Color(0xFF1877F2)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$metCount of $totalCount Completed',
                style: TextStyle(color: ThemeService.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Text(
                '${((metCount / (totalCount > 0 ? totalCount : 1)) * 100).toInt()}%',
                style: const TextStyle(color: Color(0xFF1877F2), fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementCard(VerificationRequirementItem item, GamerUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isMet ? const Color(0xFF00FF88).withOpacity(0.5) : const Color(0xFFFF4655).withOpacity(0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.icon,
                color: item.isMet ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(color: ThemeService.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      item.description,
                      style: TextStyle(color: ThemeService.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(
                item.isMet ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: item.isMet ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.progress,
              minHeight: 5,
              backgroundColor: ThemeService.cardSecondary,
              valueColor: AlwaysStoppedAnimation<Color>(item.isMet ? const Color(0xFF00FF88) : const Color(0xFFFF6B00)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.currentFormatted,
                style: TextStyle(
                  color: item.isMet ? const Color(0xFF00FF88) : ThemeService.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Target: ${item.targetFormatted}',
                style: TextStyle(color: ThemeService.textSecondary, fontSize: 10.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(GamerUser user, {required bool allMet, required bool isVerified, required bool isPending}) {
    if (isVerified) {
      return Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF1877F2).withOpacity(0.15),
          border: Border.all(color: const Color(0xFF1877F2), width: 1.5),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_rounded, color: Color(0xFF1877F2), size: 20),
              const SizedBox(width: 8),
              Text(
                LanguageService.isUrdu ? 'تصدیق شدہ بلیو ٹک ✓' : 'Official Blue Tick Verified ✓',
                style: const TextStyle(color: Color(0xFF1877F2), fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (isPending) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF8A00),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.hourglass_bottom_rounded, size: 18),
          label: Text(
            LanguageService.isUrdu ? 'زیر التوا (24 گھنٹے) ⏳' : 'Under Review 24h ⏳',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          onPressed: _isSubmitting ? null : () => _handleApply(user),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: allMet ? const Color(0xFF1877F2) : ThemeService.cardSecondary,
          foregroundColor: allMet ? Colors.white : ThemeService.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: allMet ? const Color(0xFF1877F2) : ThemeService.border),
          ),
          elevation: 0,
        ),
        icon: _isSubmitting
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Icon(allMet ? Icons.verified_rounded : Icons.lock_outline_rounded, size: 18),
        label: Text(
          allMet
              ? (LanguageService.isUrdu ? 'درخواست جمع کروائیں' : 'APPLY FOR VERIFICATION')
              : (LanguageService.isUrdu ? 'درخواست بند ہے (شرائط باقی ہیں)' : 'Apply for Verification (Locked)'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
        onPressed: _isSubmitting ? null : () => _handleApply(user),
      ),
    );
  }

  Widget _buildQuickActionShortcuts(GamerUser user) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ThemeService.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LanguageService.isUrdu ? 'شرائط پوری کرنے کے لیے فوری راستے' : 'QUICK SHORTCUTS TO COMPLETE REQUIREMENTS',
            style: TextStyle(color: ThemeService.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1877F2)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.sports_esports_rounded, color: Color(0xFF1877F2), size: 15),
                  label: Text(
                    LanguageService.isUrdu ? 'گیم یو آئی ڈی' : 'Link Game UID',
                    style: const TextStyle(color: Color(0xFF1877F2), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showLinkGameUidDialog(user),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFF6B00)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.military_tech_rounded, color: Color(0xFFFF6B00), size: 15),
                  label: Text(
                    LanguageService.isUrdu ? 'گیم رینک' : 'Set Game Rank',
                    style: const TextStyle(color: Color(0xFFFF6B00), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showQuickRankKdDialog(user),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: ThemeService.border),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: Icon(Icons.edit_note_rounded, color: ThemeService.textPrimary, size: 15),
                  label: Text(
                    LanguageService.isUrdu ? 'بائیو اور اواتار' : 'Edit Bio & Avatar',
                    style: TextStyle(color: ThemeService.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => CreateGamerIdScreen(isEditing: true, existingUser: user))).then((_) => _refreshData());
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: ThemeService.border),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: Icon(Icons.movie_creation_rounded, color: ThemeService.textPrimary, size: 15),
                  label: Text(
                    LanguageService.isUrdu ? 'پوسٹ کلپ' : 'Post Clip/Room',
                    style: TextStyle(color: ThemeService.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen())).then((_) => _refreshData());
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
