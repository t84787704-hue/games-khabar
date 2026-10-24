// ===============================================================================
// EXACT DIFF — Dynamic Thematic Avatars, Real-time Unread Count & Theme Support
// -------------------------------------------------------------------------------
// File: lib/screens/notifications_screen.dart
// ===============================================================================

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/gamer_theme.dart';
import '../models/notification_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../services/challenge_service.dart';
import '../services/theme_service.dart';
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
  final Set<String> _locallyReadIds = {};

  String get _currentUid =>
      GamerAuthService().currentUid ?? SupabaseService.client.auth.currentUser?.id ?? '';

  String _formatNotifText(String text) {
    if (text.isEmpty) return '';
    final translated = text.tr();
    return (translated.isNotEmpty && translated != text) ? translated : text;
  }

  @override
  void initState() {
    super.initState();
    _notificationService.refreshUnreadCount(_currentUid);
  }

  List<InAppNotification> _filterNotifications(List<InAppNotification> list) {
    switch (_selectedFilterIndex) {
      case 1:
        return list.where((n) => !n.isRead && !_locallyReadIds.contains(n.id)).toList();
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

  void _handleNotificationTap(InAppNotification notif) async {
    final notifId = notif.id;
    if (!notif.isRead && !_locallyReadIds.contains(notifId)) {
      setState(() {
        _locallyReadIds.add(notifId);
      });
      await _notificationService.markAsRead(notifId);
    }

    final data = notif.data ?? {};
    final matchId = data['match_id'] ?? data['matchId'];
    final senderId = notif.senderId;

    if (!mounted) return;

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
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ThemeService.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: Color(0xFFFF4655), size: 22),
            const SizedBox(width: 8),
            Text(
              'clear_all_activities_title'.tr(),
              style: const TextStyle(color: Color(0xFFFF4655), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'clear_all_activities_desc'.tr(),
          style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('btn_cancel'.tr(), style: TextStyle(color: ThemeService.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4655),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('btn_clear_all'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _localNotifications = [];
        _locallyReadIds.clear();
        _streamKey = UniqueKey();
      });

      await _notificationService.clearAll(_currentUid);

      if (mounted) {
        setState(() {
          _localNotifications = [];
          _locallyReadIds.clear();
          _streamKey = UniqueKey();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('all_notifs_cleared_msg'.tr()),
            backgroundColor: const Color(0xFF1877F2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
            title: Text(
              'activities_and_notifications_title'.tr(),
              style: TextStyle(
                color: ThemeService.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'mark_all_read_tooltip'.tr(),
                icon: const Icon(Icons.done_all_rounded, color: Color(0xFF1877F2), size: 22),
                onPressed: () async {
                  setState(() {
                    if (_localNotifications != null) {
                      for (final n in _localNotifications!) {
                        _locallyReadIds.add(n.id);
                      }
                    }
                  });
                  await _notificationService.markAllAsRead(_currentUid);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('all_marked_read_msg'.tr()),
                        backgroundColor: const Color(0xFF00FF88),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              IconButton(
                tooltip: 'clear_all_tooltip'.tr(),
                icon: Icon(Icons.delete_outline_rounded, color: ThemeService.textSecondary, size: 22),
                onPressed: _confirmClearAll,
              ),
            ],
          ),
          body: Column(
            children: [
              _buildFilterTabs(),
              Expanded(
                child: StreamBuilder<List<InAppNotification>>(
                  key: _streamKey,
                  stream: _notificationService.notificationsStream(_currentUid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData &&
                        _localNotifications == null) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF1877F2)));
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
      },
    );
  }

  Widget _buildFilterTabs() {
    final tabs = [
      {'key': 'filter_tab_all'.tr(), 'icon': Icons.all_inbox_rounded},
      {'key': 'filter_tab_unread'.tr(), 'icon': Icons.mark_email_unread_rounded},
      {'key': 'filter_tab_social'.tr(), 'icon': Icons.people_rounded},
      {'key': 'filter_tab_matches'.tr(), 'icon': Icons.sports_esports_rounded},
      {'key': 'filter_tab_coins'.tr(), 'icon': Icons.monetization_on_rounded},
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
