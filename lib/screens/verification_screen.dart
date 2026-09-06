import 'package:flutter/material.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_user_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/verification_service.dart';
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
                  'Cannot apply: ${unmet.length} requirement(s) missing with red cross.',
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
      // Step 1: Set to pending and show "Under Review 24h"
      await VerificationService.setPendingUnderReview(user.uid);
      if (mounted) {
        setState(() {
          _currentUser = user.copyWith(
            verificationStatus: 'pending',
            isVerified: false,
          );
        });
      }

      // Show brief pending transition dialog
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

      // Step 2: Auto-verify since requirements are 100% verified!
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
              'All 6 BGMI integrity & competitive requirements have been validated. Your official Blue Tick ✓ is now live on your Gamer ID and all posts!',
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

  void _showLinkBgmiUidDialog(GamerUser user) {
    final controller = TextEditingController(text: user.gameId);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GamerTheme.cardElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.sports_esports_rounded, color: GamerTheme.accentBlue, size: 22),
            SizedBox(width: 8),
            Text('Link BGMI UID', style: TextStyle(color: GamerTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Requirement 1: Enter your BGMI in-game Character ID or UID (e.g. 5129384729):',
              style: TextStyle(color: GamerTheme.textGray, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'e.g. 5129384729',
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
                await VerificationService.linkGameId(userId: user.uid, gameId: val, gameName: 'BGMI');
                _refreshData();
              }
            },
            child: const Text('Save & Link', style: TextStyle(color: GamerTheme.bgDark, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showQuickRankKdDialog(GamerUser user) {
    String selectedRank = user.rank.isEmpty ? 'Ace' : user.rank;
    final kdController = TextEditingController(text: user.kdRatio > 0 ? user.kdRatio.toString() : '3.5');

    const ranksList = [
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
              Text('Update Rank & K/D', style: TextStyle(color: GamerTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select your official BGMI Season Rank and Kill/Death (K/D) ratio:',
                style: TextStyle(color: GamerTheme.textGray, fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Text('BGMI RANK (Must be Crown/Ace+)', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
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
                    value: ranksList.contains(selectedRank) ? selectedRank : 'Ace',
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
              const Text('K/D RATIO (Min 3.0+ required)', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: kdController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'e.g. 3.50',
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
                if (kd != null) {
                  await _authService.updateProfile(
                    rank: selectedRank,
                    kdRatio: kd,
                  );
                  _refreshData();
                }
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
            const SizedBox(height: 20),

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

            // 6 Requirements Cards with Progress Bars & Red Cross ❌
            ...reqs.map((item) => _buildRequirementCard(item, user)),

            const SizedBox(height: 24),

            // Action Center / Apply Button
            _buildBottomAction(user, allMet: allMet, isVerified: isVerified, isPending: isPending),

            const SizedBox(height: 16),

            // Quick Help / Assist Actions
            if (!isVerified) _buildQuickActionShortcuts(user),
          ],
        ),
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
    if (isVerified) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D2538), Color(0xFF133E60)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.blue.withOpacity(0.8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.25),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_rounded, color: Colors.blue, size: 48),
            ),
            const SizedBox(height: 12),
            const Text(
              'Official Blue Tick Verified ✓',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '@${user.username} is an officially verified competitive BGMI player. All community integrity, K/D, and rank benchmarks are satisfied.',
              style: const TextStyle(color: GamerTheme.textGray, fontSize: 13, height: 1.35),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (isPending) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2A1C0A), Color(0xFF3F2B12)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFF8A00), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF8A00).withOpacity(0.2),
              blurRadius: 14,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8A00).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFFF8A00), size: 44),
            ),
            const SizedBox(height: 12),
            const Text(
              'Under Review 24h',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your verification application has been submitted and is currently under 24-hour review. All 6 requirements will be validated before permanent badge activation.',
              style: TextStyle(color: GamerTheme.textGray, fontSize: 12.5, height: 1.35),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.verified_rounded, size: 18),
              label: const Text('Complete Verification Review', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              onPressed: () => _handleApply(user),
            ),
          ],
        ),
      );
    }

    // Default In-Progress / Not Applied
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GamerTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.verified, color: Colors.blue, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Get The Official Blue Tick',
                      style: TextStyle(
                        color: GamerTheme.textWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'User must meet ALL 6 requirements to apply',
                      style: TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: totalCount > 0 ? metCount / totalCount : 0.0,
              minHeight: 8,
              backgroundColor: GamerTheme.cardElevated,
              valueColor: AlwaysStoppedAnimation<Color>(
                metCount == totalCount ? GamerTheme.neonGreen : GamerTheme.accentBlue,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$metCount of $totalCount Requirements Completed',
                style: const TextStyle(color: GamerTheme.textGray, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                '${((metCount / (totalCount > 0 ? totalCount : 1)) * 100).toInt()}%',
                style: TextStyle(
                  color: metCount == totalCount ? GamerTheme.neonGreen : GamerTheme.accentBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementCard(VerificationRequirementItem item, GamerUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isMet
              ? GamerTheme.neonGreen.withOpacity(0.35)
              : GamerTheme.redAccent.withOpacity(0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (item.isMet ? GamerTheme.neonGreen : GamerTheme.redAccent).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ],
                child: Icon(
                  item.icon,
                  color: item.isMet ? GamerTheme.neonGreen : GamerTheme.redAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Title & Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: GamerTheme.textWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      style: const TextStyle(color: GamerTheme.textMuted, fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Green Checkmark OR Red Cross ❌
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: item.isMet
                      ? GamerTheme.neonGreen.withOpacity(0.15)
                      : GamerTheme.redAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: item.isMet ? GamerTheme.neonGreen : GamerTheme.redAccent,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  item.isMet ? Icons.check_rounded : Icons.close_rounded,
                  color: item.isMet ? GamerTheme.neonGreen : GamerTheme.redAccent,
                  size: 16,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.progress,
              minHeight: 6,
              backgroundColor: GamerTheme.cardElevated,
              valueColor: AlwaysStoppedAnimation<Color>(
                item.isMet
                    ? GamerTheme.neonGreen
                    : (item.progress > 0 ? GamerTheme.flameOrange : GamerTheme.redAccent),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Current vs Target Values
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.currentFormatted,
                style: TextStyle(
                  color: item.isMet ? GamerTheme.neonGreen : GamerTheme.textGray,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Target: ${item.targetFormatted}',
                style: const TextStyle(
                  color: GamerTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          // Red Cross missing details if unmet
          if (!item.isMet && item.missingReason != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: GamerTheme.redAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GamerTheme.redAccent.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.close_rounded, color: GamerTheme.redAccent, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.missingReason!,
                      style: const TextStyle(
                        color: GamerTheme.redAccent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomAction(
    GamerUser user, {
    required bool allMet,
    required bool isVerified,
    required bool isPending,
  }) {
    if (isVerified) {
      return Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.blue.withOpacity(0.15),
          border: Border.all(color: Colors.blue, width: 1.5),
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_rounded, color: Colors.blue, size: 22),
              SizedBox(width: 8),
              Text(
                'Official Blue Tick Verified ✓',
                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    if (isPending) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF8A00),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: _isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.hourglass_bottom_rounded, size: 20),
          label: const Text(
            'Under Review 24h ⏳',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          onPressed: _isSubmitting ? null : () => _handleApply(user),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: allMet ? Colors.blue : GamerTheme.cardElevated,
          foregroundColor: allMet ? Colors.white : GamerTheme.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: allMet ? Colors.blue : GamerTheme.borderDark,
            ),
          ),
          elevation: allMet ? 4 : 0,
        ),
        icon: _isSubmitting
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Icon(allMet ? Icons.verified_rounded : Icons.lock_outline_rounded, size: 20),
        label: Text(
          allMet ? 'APPLY FOR VERIFICATION' : 'Apply for Verification (Locked)',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14.5,
            letterSpacing: 0.5,
            color: allMet ? Colors.white : GamerTheme.textMuted,
          ),
        ),
        onPressed: _isSubmitting ? null : () => _handleApply(user),
      ),
    );
  }

  Widget _buildQuickActionShortcuts(GamerUser user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GamerTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'QUICK SHORTCUTS TO COMPLETE REQUIREMENTS',
            style: TextStyle(
              color: GamerTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: GamerTheme.accentBlue),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.sports_esports_rounded, color: GamerTheme.accentBlue, size: 16),
                  label: const Text('Link BGMI UID', style: TextStyle(color: GamerTheme.accentBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _showLinkBgmiUidDialog(user),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: GamerTheme.flameOrange),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.military_tech_rounded, color: GamerTheme.flameOrange, size: 16),
                  label: const Text('Set Rank & K/D', style: TextStyle(color: GamerTheme.flameOrange, fontSize: 12, fontWeight: FontWeight.bold)),
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
                    side: const BorderSide(color: GamerTheme.borderLight),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.edit_note_rounded, color: GamerTheme.textWhite, size: 16),
                  label: const Text('Edit Bio & Avatar', style: TextStyle(color: GamerTheme.textWhite, fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateGamerIdScreen(isEditing: true, existingUser: user),
                      ),
                    ).then((_) => _refreshData());
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: GamerTheme.borderLight),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.movie_creation_rounded, color: GamerTheme.textWhite, size: 16),
                  label: const Text('Post Clip/Room', style: TextStyle(color: GamerTheme.textWhite, fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                    ).then((_) => _refreshData());
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
