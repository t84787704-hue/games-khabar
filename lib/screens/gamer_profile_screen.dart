// ===============================================================================
// GAMER PROFILE SCREEN — With eSports 500/1000 Coins Team Eligibility Badges
// + Full Localization (.tr())
// ===============================================================================

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:share_plus/share_plus.dart';
import '../services/gamer_auth_service.dart';
import '../services/theme_service.dart';
import '../models/gamer_user_model.dart';
import 'create_gamer_id_screen.dart';
import '../widgets/gamer_avatar.dart';

class GamerProfileScreen extends StatefulWidget {
  final String? userId;

  const GamerProfileScreen({super.key, this.userId});

  @override
  State<GamerProfileScreen> createState() => _GamerProfileScreenState();
}

class _GamerProfileScreenState extends State<GamerProfileScreen> {
  final GamerAuthService _auth = GamerAuthService();
  bool _isLoading = true;
  GamerUser? _profileUser;
  bool _isOwnProfile = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    final currentUid = _auth.currentGamer?.uid ?? _auth.currentUid;

    if (widget.userId == null || widget.userId == currentUid) {
      _isOwnProfile = true;
      if (_auth.currentGamer != null) {
        _profileUser = _auth.currentGamer;
      } else {
        _profileUser = await _auth.refreshCurrentGamer();
      }
    } else {
      _isOwnProfile = false;
      _profileUser = await _auth.getGamerProfile(widget.userId!);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _shareProfile(GamerUser user) {
    final shareText = '''
🎮 Gamers ID Profile: ${user.displayName} (@${user.username})
🏆 Main Game: ${user.favoriteGame}
🎯 Rank: ${user.gameRank}
💰 G-Coins: ${user.coins}

Gamers ID App par mujhe follow karein!
Download: https://play.google.com/store/apps/details?id=com.gamersid.app
''';
    Share.share(shareText.trim(), subject: 'Gamers ID - ${user.displayName}');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: ThemeService.bg,
          appBar: AppBar(
            backgroundColor: ThemeService.appBarBg,
            elevation: 0,
            title: Text(
              _isOwnProfile ? 'my_profile'.tr() : 'user_profile'.tr(),
              style: TextStyle(
                color: ThemeService.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            actions: [
              if (_profileUser != null)
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Color(0xFF1877F2)),
                  tooltip: 'share_profile'.tr(),
                  onPressed: () => _shareProfile(_profileUser!),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _profileUser == null
                  ? _buildEmptyProfile()
                  : RefreshIndicator(
                      onRefresh: _loadProfile,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            _buildProfileHeader(_profileUser!),
                            const SizedBox(height: 16),
                            _buildStatsCard(_profileUser!),
                            const SizedBox(height: 16),
                            _buildGameDetailsCard(_profileUser!),
                            const SizedBox(height: 16),
                            _buildTeamEligibilityCard(_profileUser!),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
        );
      },
    );
  }

  Widget _buildEmptyProfile() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 64, color: ThemeService.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'gamer_id_not_found'.tr(),
              style: TextStyle(color: ThemeService.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Gamer ID not created yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ThemeService.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            if (_isOwnProfile)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add),
                label: Text('create_your_gamer_id'.tr()),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateGamerIdScreen()),
                  ).then((_) => _loadProfile());
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(GamerUser user) {
    return Container(
      color: ThemeService.card,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          GamerAvatar(
            photoUrl: user.avatarUrl,
            displayName: user.displayName,
            radius: 46,
            showBorder: true,
            borderColor: const Color(0xFF1877F2),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user.displayName,
                style: TextStyle(
                  color: ThemeService.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (user.isVerified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified, color: Color(0xFF1877F2), size: 18),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '@${user.username}',
            style: TextStyle(color: ThemeService.textSecondary, fontSize: 14),
          ),
          if (user.bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                user.bio,
                textAlign: TextAlign.center,
                style: TextStyle(color: ThemeService.textPrimary, fontSize: 14),
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (_isOwnProfile)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeService.cardSecondary,
                foregroundColor: ThemeService.textPrimary,
                elevation: 0,
                side: BorderSide(color: ThemeService.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text('edit_profile'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateGamerIdScreen(isEditing: true)),
                ).then((_) => _loadProfile());
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(GamerUser user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ThemeService.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('G-Coins', '${user.coins}', Icons.monetization_on, Colors.amber),
          _buildDivider(),
          _buildStatItem('Rank', user.gameRank, Icons.military_tech, const Color(0xFF1877F2)),
          _buildDivider(),
          _buildStatItem('Followers', '${user.followersCount}', Icons.people_outline, Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: ThemeService.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 36,
      width: 1,
      color: ThemeService.border,
    );
  }

  Widget _buildGameDetailsCard(GamerUser user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ThemeService.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Game Details',
            style: TextStyle(
              color: ThemeService.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          _buildDetailRow('main_game'.tr(), user.favoriteGame),
          const SizedBox(height: 10),
          _buildDetailRow('game_uid'.tr(), user.gameUid.isNotEmpty ? user.gameUid : '---'),
          const SizedBox(height: 10),
          _buildDetailRow('In-Game Name', user.inGameName.isNotEmpty ? user.inGameName : '---'),
          const SizedBox(height: 10),
          _buildDetailRow('Rank Tier', user.gameRank),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: ThemeService.textSecondary, fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            color: ThemeService.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamEligibilityCard(GamerUser user) {
    final isLeaderEligible = user.coins >= 1000;
    final isMemberEligible = user.coins >= 500;

    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (isLeaderEligible) {
      badgeColor = Colors.green;
      badgeText = 'esports_leader_eligible'.tr();
      badgeIcon = Icons.shield_rounded;
    } else if (isMemberEligible) {
      badgeColor = Colors.amber;
      badgeText = 'esports_member_eligible'.tr();
      badgeIcon = Icons.shield_outlined;
    } else {
      badgeColor = Colors.red;
      badgeText = 'esports_ineligible'.tr();
      badgeIcon = Icons.warning_amber_rounded;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(badgeIcon, color: badgeColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'esports_team_status'.tr(),
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}