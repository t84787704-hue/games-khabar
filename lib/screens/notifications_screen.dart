import 'package:flutter/material.dart';
import '../constants/gamer_theme.dart';
import '../models/notification_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../services/challenge_service.dart';
import '../widgets/gamer_avatar.dart';
import 'gamer_profile_screen.dart';
import 'team_match_room_screen.dart';
import 'coin_wallet_screen.dart';
import 'coin_store_screen.dart';
import 'gamer_rooms_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  int _selectedFilterIndex = 0; // 0: All, 1: Unread, 2: Social, 3: Matches, 4: Coins
  List<InAppNotification>? _localNotifications;
  Key _streamKey = UniqueKey();

  String get _currentUid =>
      GamerAuthService().currentUid ?? SupabaseService.client.auth.currentUser?.id ?? '';

  List<InAppNotification> _filterNotifications(List<InAppNotification> list) {
    switch (_selectedFilterIndex) {
      case 1:
        return list.where((n) => !n.isRead).toList();
      case 2:
        return list.where((n) =>
            n.type == 'follow' ||
            n.type == 'post_like' ||
            n.type == 'like' ||
            n.type == 'post_comment' ||
            n.type == 'comment').toList();
      case 3:
        return list.where((n) =>
            n.type.contains('challenge') ||
            n.type.contains('team') ||
            n.type.contains('proof') ||
            n.type.contains('match') ||
            n.type.contains('tournament') ||
            n.type.contains('room')).toList();
      case 4:
        return list.where((n) =>
            n.type.contains('coin') ||
            n.type.contains('store') ||
            n.type.contains('perk') ||
            n.type.contains('bonus') ||
            n.type.contains('reward')).toList();
      case 0:
      default:
        return list;
    }
  }

  void _handleNotificationTap(InAppNotification notif) {
    if (!notif.isRead) {
      _notificationService.markAsRead(notif.id);
    }

    final data = notif.data ?? {};
    final matchId = data['match_id'] ?? data['matchId'];
    final roomId = data['room_id'] ?? data['roomId'];
    final senderId = notif.senderId;

    if (notif.type.contains('coin') ||
        notif.type.contains('bonus') ||
        notif.type.contains('reward') ||
        notif.type == 'welcome_bonus') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CoinWalletScreen()));
      return;
    }

    if (notif.type == 'store_purchase' || notif.type == 'perk_expiry') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CoinStoreScreen()));
      return;
    }

    if (notif.type.contains('dispute') ||
        notif.type.contains('room') ||
        notif.type.contains('proof') ||
        notif.type.contains('tournament')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const GamerRoomsScreen()));
      return;
    }

    if (matchId != null && matchId.toString().isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TeamMatchRoomScreen(matchId: matchId.toString())),
      );
      return;
    }

    if (senderId != null && senderId.isNotEmpty && senderId != 'admin' && senderId != _currentUid) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GamerProfileScreen(userId: senderId)),
      );
      return;
    }
  }

  Future<void> _confirmClearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101726),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: GamerTheme.borderDark),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: GamerTheme.redAccent, size: 22),
            SizedBox(width: 8),
            Text('Clear All Activity?', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          'This will permanently delete all your notifications.',
          style: TextStyle(color: GamerTheme.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: GamerTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GamerTheme.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('CLEAR ALL'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Immediate local state clear (Issue #7)
      setState(() {
        _localNotifications = [];
        _streamKey = UniqueKey();
      });

      // Actual DB delete via NotificationService.clearAll (Issue #7)
      await _notificationService.clearAll(_currentUid);

      if (mounted) {
        setState(() {
          _localNotifications = [];
          _streamKey = UniqueKey();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications cleared.'),
            backgroundColor: GamerTheme.accentBlue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B101B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B101B),
        elevation: 0,
        title: const Text(
          'Gamer Activity',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Mark all read',
            icon: const Icon(Icons.done_all_rounded, color: GamerTheme.accentBlue, size: 22),
            onPressed: () async {
              await _notificationService.markAllAsRead(_currentUid);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications marked as read.'),
                    backgroundColor: GamerTheme.neonGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Clear all',
            icon: const Icon(Icons.delete_outline_rounded, color: GamerTheme.textMuted, size: 22),
            onPressed: _confirmClearAll,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          _buildFilterTabs(),

          // Notifications List
          Expanded(
            child: StreamBuilder<List<InAppNotification>>(
              key: _streamKey,
              stream: _notificationService.notificationsStream(_currentUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData &&
                    _localNotifications == null) {
                  return const Center(child: CircularProgressIndicator(color: GamerTheme.accentBlue));
                }

                if (snapshot.hasData) {
                  _localNotifications = snapshot.data;
                }

                final allNotifs = _localNotifications ?? snapshot.data ?? [];
                final filtered = _filterNotifications(allNotifs);

                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final notif = filtered[index];
                    return _buildNotificationCard(notif);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final tabs = [
      {'label': 'All', 'icon': Icons.all_inbox_rounded},
      {'label': 'Unread', 'icon': Icons.mark_email_unread_rounded},
      {'label': 'Social', 'icon': Icons.people_rounded},
      {'label': 'Matches', 'icon': Icons.sports_esports_rounded},
      {'label': 'Coins', 'icon': Icons.monetization_on_rounded},
    ];

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final isSelected = _selectedFilterIndex == idx;
          final tab = tabs[idx];
          return GestureDetector(
            onTap: () => setState(() => _selectedFilterIndex = idx),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? GamerTheme.accentBlue.withOpacity(0.18) : GamerTheme.cardDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? GamerTheme.accentBlue : GamerTheme.borderDark,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    tab['icon'] as IconData,
                    size: 14,
                    color: isSelected ? GamerTheme.accentBlue : GamerTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tab['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : GamerTheme.textMuted,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(InAppNotification notif) {
    final senderName = notif.senderName ?? 'System Notification';
    final senderPhoto = notif.senderAvatar ?? '';
    final senderId = notif.senderId ?? '';

    return Dismissible(
      key: Key(notif.id.isNotEmpty ? notif.id : UniqueKey().toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: GamerTheme.redAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_rounded, color: GamerTheme.redAccent, size: 24),
      ),
      onDismissed: (_) {
        setState(() {
          _localNotifications?.removeWhere((item) => item.id == notif.id);
        });
        _notificationService.deleteNotification(notif.id);
      },
      child: Container(
        decoration: BoxDecoration(
          color: notif.isRead ? const Color(0xFF101726) : const Color(0xFF141F33),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notif.isRead ? GamerTheme.borderDark : GamerTheme.accentBlue.withOpacity(0.35),
            width: notif.isRead ? 1.0 : 1.4,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _handleNotificationTap(notif),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar with overlay badge
                      Stack(
                        children: [
                          GamerAvatar(
                            photoUrl: senderPhoto,
                            displayName: senderName,
                            radius: 20,
                            onTap: () {
                              if (senderId.isNotEmpty && senderId != 'admin' && senderId != _currentUid) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => GamerProfileScreen(userId: senderId)),
                                );
                              }
                            },
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Color(0xFF0B101B),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(notif.iconData, color: notif.iconColor, size: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // Title & Body
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    notif.title,
                                    style: TextStyle(
                                      color: notif.isRead ? Colors.white70 : Colors.white,
                                      fontSize: 13.5,
                                      fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: notif.iconColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    notif.categoryTag,
                                    style: TextStyle(
                                      color: notif.iconColor,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              notif.body,
                              style: TextStyle(
                                color: notif.isRead ? GamerTheme.textMuted : GamerTheme.textWhite,
                                fontSize: 12.5,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              notif.timeAgo,
                              style: const TextStyle(
                                color: GamerTheme.textMuted,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Unread blue indicator
                      if (!notif.isRead)
                        Padding(
                          padding: const EdgeInsets.only(left: 6, top: 4),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: GamerTheme.accentBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Action buttons if interactive notification
                  _buildInteractiveActions(notif),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveActions(InAppNotification notif) {
    final data = notif.data ?? {};
    final challengeId = data['challenge_id'] ?? data['challengeId'];
    final matchId = data['match_id'] ?? data['matchId'];

    // 1v1 Challenge
    if (notif.type == 'challenge_received' && challengeId != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10, left: 52),
        child: Row(
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2D55),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: Size.zero,
              ),
              onPressed: () async {
                await ChallengeService().acceptChallenge(
                  challengeId.toString(),
                  challengerUid: notif.senderId ?? '',
                  responderName: GamerAuthService().currentGamer?.displayName ?? 'Opponent',
                );
                await _notificationService.markAsRead(notif.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚔️ 1v1 Challenge Accepted! Match room is ready.'),
                      backgroundColor: GamerTheme.neonGreen,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('ACCEPT ⚔️', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: GamerTheme.borderLight),
                foregroundColor: GamerTheme.textMuted,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: Size.zero,
              ),
              onPressed: () async {
                await ChallengeService().declineChallenge(challengeId.toString());
                await _notificationService.markAsRead(notif.id);
              },
              child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ],
        ),
      );
    }

    // Room / Dispute action button
    if (notif.type.contains('dispute') ||
        notif.type.contains('room') ||
        notif.type.contains('proof') ||
        notif.type.contains('tournament')) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, left: 52),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: notif.iconColor),
            foregroundColor: notif.iconColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
          ),
          icon: const Icon(Icons.meeting_room_rounded, size: 12),
          label: const Text('Open Rooms', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          onPressed: () {
            _notificationService.markAsRead(notif.id);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const GamerRoomsScreen()));
          },
        ),
      );
    }

    // Match Room action
    if (matchId != null && matchId.toString().isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, left: 52),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: notif.iconColor),
            foregroundColor: notif.iconColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
          ),
          icon: const Icon(Icons.open_in_new_rounded, size: 12),
          label: const Text('Open Match Room', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          onPressed: () {
            _notificationService.markAsRead(notif.id);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TeamMatchRoomScreen(matchId: matchId.toString())),
            );
          },
        ),
      );
    }

    // Coin Wallet action
    if (notif.type.contains('coin') || notif.type.contains('proof_accepted')) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, left: 52),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFFFD700)),
            foregroundColor: const Color(0xFFFFD700),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
          ),
          icon: const Text('🪙', style: TextStyle(fontSize: 12)),
          label: const Text('View Wallet', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          onPressed: () {
            _notificationService.markAsRead(notif.id);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CoinWalletScreen()));
          },
        ),
      );
    }

    // Coin Store action
    if (notif.type == 'store_purchase' || notif.type == 'perk_expiry') {
      return Padding(
        padding: const EdgeInsets.only(top: 8, left: 52),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF00E5FF)),
            foregroundColor: const Color(0xFF00E5FF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
          ),
          icon: const Icon(Icons.storefront_rounded, size: 12),
          label: const Text('Open Coin Store', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          onPressed: () {
            _notificationService.markAsRead(notif.id);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CoinStoreScreen()));
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: GamerTheme.cardDark,
                shape: BoxShape.circle,
                border: Border.all(color: GamerTheme.borderDark),
              ),
              child: const Icon(Icons.notifications_none_rounded, color: GamerTheme.textMuted, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilterIndex == 1
                  ? 'No unread notifications'
                  : 'No notifications yet',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'When gamers follow you, challenge your team, or your match proofs are approved, updates appear here!',
              textAlign: TextAlign.center,
              style: TextStyle(color: GamerTheme.textMuted, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}