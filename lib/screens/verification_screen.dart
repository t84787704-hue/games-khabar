// ===============================================================================
// VERIFICATION SCREEN — Strict Rules & Early Bird 1200 VIP Tier
// File: lib/screens/verification_screen.dart
// ===============================================================================

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/gamer_user_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/verification_service.dart';
import '../services/supabase_service.dart';
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
  VerificationStats? _liveStats;
  GamerUser? _currentUser;

  bool _isEarlyBirdUser = false;
  int _userRegistrationRank = 0;
  int _referralCount = 0;

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
        await _checkEarlyBirdStatus(uid);

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

  Future<void> _checkEarlyBirdStatus(String uid) async {
    try {
      final userRes = await SupabaseService.client
          .from('users')
          .select('created_at, referred_by')
          .or('id.eq.$uid,uid.eq.$uid')
          .maybeSingle();

      if (userRes != null && userRes['created_at'] != null) {
        final userCreatedAt = userRes['created_at'];

        final countRes = await SupabaseService.client
            .from('users')
            .select('id')
            .lte('created_at', userCreatedAt)
            .count();

        _userRegistrationRank = countRes.count;
        _isEarlyBirdUser = _userRegistrationRank <= 1200;
      }

      final refRes = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('referred_by', uid)
          .count();

      _referralCount = refRes.count;
    } catch (e) {
      debugPrint('Error checking early bird/referral status: $e');
    }
  }

  Future<void> _handleApply(GamerUser user) async {
    bool canApply = false;

    if (_isEarlyBirdUser) {
      canApply = _referralCount >= 2;
    } else {
      final standardMet = VerificationService.canApplyForVerification(
        user,
        clipsCount: _liveStats?.clipsCount,
        squadRoomsCount: _liveStats?.squadRoomsCount,
        likesReceived: _liveStats?.likesReceived,
        reportsCount: _liveStats?.reportsCount,
        accountAgeDays: _liveStats?.accountAgeDays,
      );
      canApply = standardMet && (_referralCount >= 2);
    }

    if (!canApply) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFFF4655),
          content: Text(
            _isEarlyBirdUser
                ? 'Aapko verification ke liye kam az kam 2 doston ko refer karna zaroori hai (${_referralCount}/2 Completed)!'
                : 'Pehle tamam requirements aur minimum 2 Referrals poore karein!',
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
          SnackBar(
            backgroundColor: const Color(0xFFFF4655),
            content: Text('err_failed_with_msg'.tr(args: [e.toString()])),
          ),
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
              'dialog_verified_celebration_title'.tr(),
              style: TextStyle(color: ThemeService.textPrimary, fontSize: 20, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'dialog_verified_celebration_desc'.tr(),
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
                  'btn_lets_flex'.tr(),
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
            'dialog_link_game_uid_title'.tr(),
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
                  labelText: 'label_select_game'.tr(),
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
                  labelText: 'label_character_uid'.tr(),
                  labelStyle: TextStyle(color: ThemeService.textSecondary),
                  hintText: 'hint_character_uid'.tr(),
                  hintStyle: TextStyle(color: ThemeService.textSecondary.withOpacity(0.5)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'cancel'.tr(),
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
                'save'.tr(),
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
            'dialog_rank_in_game_title'.tr(args: [selectedGame]),
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
                'cancel'.tr(),
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
                'btn_update'.tr(),
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
                        'title_blue_tick_verification'.tr(),
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: ThemeService.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1877F2)),
                    tooltip: 'tooltip_refresh'.tr(),
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

    final bool isVerified = user.isVerified || user.verificationStatus == 'verified';
    final bool isPending = user.verificationStatus == 'pending' && !isVerified;

    final bool referralMet = _referralCount >= 2;
    final int metCount = reqs.where((r) => r.isMet).length + (referralMet ? 1 : 0);
    final int totalCount = reqs.length + 1;

    final bool allMet = _isEarlyBirdUser ? referralMet : (metCount == totalCount);

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
            _buildStatusHeaderCard(user, isVerified: isVerified, isPending: isPending, metCount: metCount, totalCount: totalCount),
            const SizedBox(height: 16),

            if (!isVerified) ...[
              _buildEarlyBirdOfferCard(),
              const SizedBox(height: 18),
            ],

            _buildReferralRequirementCard(referralMet),
            const SizedBox(height: 16),

            if (!_isEarlyBirdUser) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'mandatory_requirements_title'.tr(),
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
                      '$metCount / $totalCount Met',
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
            ],

            const SizedBox(height: 24),

            _buildBottomAction(user, allMet: allMet, isVerified: isVerified, isPending: isPending),

            const SizedBox(height: 16),

            if (!isVerified && !_isEarlyBirdUser) _buildQuickActionShortcuts(user),
          ],
        ),
      ),
    );
  }

  Widget _buildEarlyBirdOfferCard() {
    final isDark = ThemeService.isDarkMode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isEarlyBirdUser
            ? (isDark ? const Color(0xFF1E2818) : const Color(0xFFEFFDEB))
            : (isDark ? const Color(0xFF221C18) : const Color(0xFFFFF8F0)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isEarlyBirdUser ? const Color(0xFF00FF88) : const Color(0xFFFF8A00),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isEarlyBirdUser ? Icons.stars_rounded : Icons.info_outline_rounded,
                color: _isEarlyBirdUser ? const Color(0xFF00FF88) : const Color(0xFFFF8A00),
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isEarlyBirdUser
                      ? 'Early Bird VIP: First 1200 Users! 🎉'
                      : 'First 1200 Users Offer Ended',
                  style: TextStyle(
                    color: _isEarlyBirdUser ? const Color(0xFF00FF88) : const Color(0xFFFF8A00),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isEarlyBirdUser
                ? 'Mubarak ho! Aap app ke pehle 1,200 users mein shamil hain (#$_userRegistrationRank). Aapke liye baqi tamam requirements exempted hain — sirf 2 Friends ko refer karein aur Blue Tick unlock karein!'
                : 'Pehle 1,200 users ka quota mukammal ho chuka hai. Regular users ko Blue Tick ke liye neeche diye gaye tamam strict rules poore karne honge.',
            style: TextStyle(color: ThemeService.textPrimary, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralRequirementCard(bool isMet) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMet ? const Color(0xFF00FF88).withOpacity(0.5) : const Color(0xFFFF4655).withOpacity(0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.people_alt_rounded,
                color: isMet ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invite & Refer 2 Active Gamers',
                      style: TextStyle(color: ThemeService.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Aapke referral link/code se kam az kam 2 doston ka join hona lazmi hai.',
                      style: TextStyle(color: ThemeService.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(
                isMet ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: isMet ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_referralCount / 2).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: ThemeService.cardSecondary,
              valueColor: AlwaysStoppedAnimation<Color>(isMet ? const Color(0xFF00FF88) : const Color(0xFFFF6B00)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_referralCount Joined',
                style: TextStyle(
                  color: isMet ? const Color(0xFF00FF88) : ThemeService.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'Target: 2 Referrals',
                style: TextStyle(color: Color(0xFF65676B), fontSize: 10.5),
              ),
            ],
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
            Text('owner_creator_badge'.tr(), style: const TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('owner_creator_desc'.tr(), style: TextStyle(color: ThemeService.textPrimary, fontSize: 13)),
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
              'status_verified_blue_tick'.tr(),
              style: TextStyle(color: ThemeService.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'status_verified_gamer_desc'.tr(args: [user.username]),
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
              'status_under_review_24h'.tr(),
              style: TextStyle(color: ThemeService.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Admin review jari hai. Jald verification status update ho jayega.',
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
                      'get_official_blue_tick_title'.tr(),
                      style: TextStyle(color: ThemeService.textPrimary, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      _isEarlyBirdUser
                          ? 'Early Bird VIP: Just 2 Referrals Needed'
                          : 'meet_all_requirements_sub'.tr(),
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
              value: _isEarlyBirdUser
                  ? (_referralCount / 2).clamp(0.0, 1.0)
                  : (totalCount > 0 ? metCount / totalCount : 0.0),
              minHeight: 7,
              backgroundColor: ThemeService.cardSecondary,
              valueColor: AlwaysStoppedAnimation<Color>(
                (_isEarlyBirdUser ? _referralCount >= 2 : metCount == totalCount)
                    ? const Color(0xFF00FF88)
                    : const Color(0xFF1877F2),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isEarlyBirdUser
                    ? 'Referrals: $_referralCount / 2'
                    : 'completed_of_total'.tr(args: ['$metCount', '$totalCount']),
                style: TextStyle(color: ThemeService.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Text(
                _isEarlyBirdUser
                    ? '${((_referralCount / 2).clamp(0.0, 1.0) * 100).toInt()}%'
                    : '${((metCount / (totalCount > 0 ? totalCount : 1)) * 100).toInt()}%',
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
                'target_label'.tr(args: [item.targetFormatted]),
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
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_rounded, color: Color(0xFF1877F2), size: 20),
              SizedBox(width: 8),
              Text(
                'Official Verified Gamer',
                style: TextStyle(color: Color(0xFF1877F2), fontWeight: FontWeight.w900, fontSize: 14),
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
          icon: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.hourglass_bottom_rounded, size: 18),
          label: Text(
            'btn_under_review_24h'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          onPressed: null,
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
        icon: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Icon(allMet ? Icons.verified_rounded : Icons.lock_outline_rounded, size: 18),
        label: Text(
          allMet
              ? 'Apply for Official Verification'
              : 'btn_apply_locked'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
        onPressed: allMet && !_isSubmitting ? () => _handleApply(user) : null,
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
            'quick_shortcuts_title'.tr(),
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
                    'btn_shortcut_link_uid'.tr(),
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
                    'btn_shortcut_set_rank'.tr(),
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
                    'btn_shortcut_edit_bio'.tr(),
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
                  icon: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF1877F2), size: 15),
                  label: const Text(
                    'Post Picture',
                    style: TextStyle(color: Color(0xFF1877F2), fontSize: 11, fontWeight: FontWeight.bold),
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
