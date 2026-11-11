import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_user_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_social_service.dart';
import '../services/supabase_service.dart';
import '../services/theme_service.dart';
import '../widgets/gamer_avatar.dart';
import 'gamer_profile_screen.dart';

typedef FollowersFollowingScreen = SquadAlliesScreen;

class SquadAlliesScreen extends StatefulWidget {
  final String userId;
  final String displayName;
  final int initialTabIndex; // 0 = Squad, 1 = Allies

  const SquadAlliesScreen({
    super.key,
    required this.userId,
    required this.displayName,
    this.initialTabIndex = 0,
  });

  @override
  State<SquadAlliesScreen> createState() => _SquadAlliesScreenState();
}

class _SquadAlliesScreenState extends State<SquadAlliesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GamerSocialService _socialService = GamerSocialService();
  final GamerAuthService _authService = GamerAuthService();

  List<GamerUser> _squadMembers = [];
  List<GamerUser> _allies = [];
  bool _loadingSquad = true;
  bool _loadingAllies = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isSelfUser(GamerUser u, String currentUid, String pageOwnerId) {
    final targetId = u.uid.trim().toLowerCase();
    final curId = currentUid.trim().toLowerCase();
    final ownerId = pageOwnerId.trim().toLowerCase();
    final curUuid = SupabaseService.toUuid(curId).toLowerCase();
    final ownerUuid = SupabaseService.toUuid(ownerId).toLowerCase();

    if (targetId.isNotEmpty) {
      if (targetId == curId || targetId == ownerId) return true;
      if (targetId == curUuid || targetId == ownerUuid) return true;
    }

    final curUsername = (_authService.currentGamer?.username ?? '').trim().toLowerCase();
    if (curUsername.isNotEmpty && u.username.trim().toLowerCase() == curUsername) {
      return true;
    }

    return false;
  }

  Future<void> _loadData() async {
    setState(() {
      _loadingSquad = true;
      _loadingAllies = true;
    });

    final currentUid = _authService.currentUid ?? '';
    final results = await Future.wait<List<GamerUser>>([
      _socialService.getSquadMembers(widget.userId),
      _socialService.getAllies(widget.userId),
    ]);
    final squadMembers = results[0];
    final allies = results[1];

    if (mounted) {
      setState(() {
        _squadMembers = squadMembers
            .where((u) => !_isSelfUser(u, currentUid, widget.userId))
            .toList();
        _allies = allies
            .where((u) => !_isSelfUser(u, currentUid, widget.userId))
            .toList();

        _loadingSquad = false;
        _loadingAllies = false;
      });
    }
  }

  Widget _buildUserList(List<GamerUser> list, bool isLoading, String emptyLabel) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1877F2)));
    }

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups_outlined, color: ThemeService.textSecondary, size: 48),
            const SizedBox(height: 12),
            Text(emptyLabel, style: TextStyle(color: ThemeService.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    final currentUid = _authService.currentUid ?? '';

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: list.length,
      separatorBuilder: (_, __) => Divider(color: ThemeService.border, height: 1),
      itemBuilder: (context, index) {
        final user = list[index];
        final effectiveUserId = user.uid;
        final isSelf = _isSelfUser(user, currentUid, widget.userId);
        final gameColor = GamerTheme.gameColors[user.favoriteGame] ?? const Color(0xFF1877F2);
        final gameEmoji = GamerTheme.gameEmojis[user.favoriteGame] ?? '🎮';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
          leading: GamerAvatar(
            photoUrl: user.photoUrl,
            displayName: user.displayName,
            radius: 22,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => GamerProfileScreen(userId: effectiveUserId)),
              );
            },
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  user.displayName.isNotEmpty ? user.displayName : user.username,
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (user.hasBlueTick) ...[
                const SizedBox(width: 4),
                const Icon(Icons.verified, color: Color(0xFF1D9BF0), size: 14),
              ],
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                Text(
                  '@${user.username}',
                  style: const TextStyle(
                    color: Color(0xFFFF8A00),
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: gameColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$gameEmoji ${user.favoriteGame}',
                    style: TextStyle(color: gameColor, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          trailing: isSelf
              ? null
              : StreamBuilder<bool>(
                  stream: _socialService.isAllyStream(currentUid, effectiveUserId),
                  builder: (context, snap) {
                    final isAlly = snap.data ?? false;
                    return SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          backgroundColor: isAlly ? ThemeService.cardSecondary : const Color(0xFF1877F2),
                          foregroundColor: isAlly ? ThemeService.textPrimary : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isAlly ? ThemeService.border : Colors.transparent,
                            ),
                          ),
                        ),
                        onPressed: () async {
                          if (isAlly) {
                            await _socialService.removeAlly(
                              currentUid: currentUid,
                              targetUid: effectiveUserId,
                            );
                          } else {
                            await _socialService.addAlly(
                              currentUid: currentUid,
                              targetUid: effectiveUserId,
                            );
                          }
                          _loadData();
                        },
                        child: Text(
                          isAlly ? 'btn_allied'.tr() : 'btn_add_ally'.tr(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isAlly ? ThemeService.textPrimary : Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => GamerProfileScreen(userId: effectiveUserId)),
            );
          },
        );
      },
    );
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
            elevation: ThemeService.isDarkMode ? 0 : 1,
            iconTheme: IconThemeData(color: ThemeService.textPrimary),
            title: Text(
              'squad_allies_title'.tr(args: [widget.displayName]),
              style: TextStyle(
                color: ThemeService.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF1877F2),
              indicatorWeight: 3,
              labelColor: const Color(0xFF1877F2),
              unselectedLabelColor: ThemeService.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              tabs: [
                Tab(text: 'tab_squad_count'.tr(args: ['${_squadMembers.length}'])),
                Tab(text: 'tab_allies_count'.tr(args: ['${_allies.length}'])),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildUserList(_squadMembers, _loadingSquad, 'no_squad_members_yet'.tr()),
              _buildUserList(_allies, _loadingAllies, 'no_allies_yet'.tr()),
            ],
          ),
        );
      },
    );
  }
}
