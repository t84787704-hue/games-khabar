// ═══════════════════════════════════════════════════════════════════════════════
// COMPLETE GAMER ROOMS SCREEN (WITH DYNAMIC DAY & NIGHT MODE SUPPORT)
// - Multi-Proof Preservation: Both Host & Opponent proofs saved without overwrite
// - Max 2 Active Rooms per user limit (auto-enforced on '+' click & save)
// - 5-Minute Golden Winner Banner with Live Countdown Timer
// - Auto-delete room from database after 5 minutes of completion
// - Realtime Joined Players List with Avatars, Names, IGN & Game UID
// - 1-Time Game ID & IGN Auto-Save Popup (Multi-Game Ready)
// - Join Match Button for non-host players with slot reservation
// - WINNER vs OPPONENT DISPLAY: Banner & player list show who defeated whom
// - Full Adaptive Day/Night Theme Sync with ThemeService
// - Match Verification Rules Dialog Integrated (Create, Join & In-Room)
// - Accurate Under Review vs Rejected Proof States & Banners
// - Flexible Match Formats (1v1, 2v2, 4v4 TDM)
// - Dispute management & Admin approval flow
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/gamer_theme.dart';
import '../services/gamer_auth_service.dart';
import '../services/tournament_service.dart';
import '../services/coin_wallet_service.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../services/theme_service.dart';
import '../widgets/gamer_avatar.dart';
import '../widgets/match_rules_dialog.dart';

class GamerRoom {
  final String id;
  final String hostId;
  final String game;
  final String mode;
  final String roomId;
  final String roomPassword;
  final int prizePool;
  final int totalSlots;
  final int filledSlots;
  final String status;
  final DateTime createdAt;
  final String hostName;
  final List<String> joinedUserIds;
  final List<Map<String, dynamic>> joinedUsers;
  final DateTime startTime;
  final String rewardStatus;
  final String? winnerId;
  final String? winnerName;
  final String? winProofUrl;
  final String? hostProofUrl;
  final String? opponentProofUrl;
  final List<Map<String, dynamic>> proofs;
  final DateTime? winProofUploadedAt;
  final DateTime? completedAt;
  final DateTime? autoApproveAt;
  final bool disputed;
  final String? disputedBy;
  final String? disputedByName;
  final String? disputeReason;
  final DateTime? disputedAt;
  final int entryFeeCoins;

  const GamerRoom({
    required this.id,
    required this.hostId,
    required this.game,
    required this.mode,
    required this.roomId,
    required this.roomPassword,
    required this.prizePool,
    required this.totalSlots,
    required this.filledSlots,
    required this.status,
    required this.createdAt,
    this.hostName = 'Host',
    this.joinedUserIds = const [],
    this.joinedUsers = const [],
    DateTime? startTime,
    this.rewardStatus = 'idle',
    this.winnerId,
    this.winnerName,
    this.winProofUrl,
    this.hostProofUrl,
    this.opponentProofUrl,
    this.proofs = const [],
    this.winProofUploadedAt,
    this.completedAt,
    this.autoApproveAt,
    this.disputed = false,
    this.disputedBy,
    this.disputedByName,
    this.disputeReason,
    this.disputedAt,
    this.entryFeeCoins = 0,
  }) : startTime = startTime ?? createdAt;

  String get title => '$game $mode';
  bool get isFull => filledSlots >= totalSlots;
  bool get isCompleted =>
      status.toLowerCase() == 'completed' || rewardStatus.toLowerCase() == 'sent';
  bool get isDisputed =>
      disputed || status.toLowerCase() == 'disputed' || status.toLowerCase() == 'under_review';

  bool get isRejected =>
      status.toLowerCase() == 'rejected' || rewardStatus.toLowerCase() == 'rejected';

  bool get isProofSubmitted =>
      !isCompleted &&
      !isRejected &&
      (status.toLowerCase() == 'proof_submitted' ||
          status.toLowerCase() == 'review_pending' ||
          (winProofUrl != null && winProofUrl!.isNotEmpty) ||
          proofs.isNotEmpty);

  factory GamerRoom.fromSupabase(Map<String, dynamic> row) {
    DateTime created = DateTime.now();
    if (row['created_at'] is String) {
      created = DateTime.tryParse(row['created_at']) ?? created;
    }

    List<String> joinedUserIds = <String>[];
    final rawIds = row['joined_user_ids'];
    if (rawIds is List) {
      joinedUserIds = List<String>.from(rawIds.map((e) => e.toString()));
    } else if (rawIds is String && rawIds.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawIds);
        if (decoded is List) {
          joinedUserIds = List<String>.from(decoded.map((e) => e.toString()));
        }
      } catch (_) {}
    }

    final joinedUsers = <Map<String, dynamic>>[];
    final rawUsers = row['joined_users'];
    List<dynamic> usersRawList = <dynamic>[];
    if (rawUsers is List) {
      usersRawList = rawUsers;
    } else if (rawUsers is String && rawUsers.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawUsers);
        if (decoded is List) usersRawList = decoded;
      } catch (_) {}
    }
    for (final item in usersRawList) {
      if (item is Map) {
        joinedUsers.add(Map<String, dynamic>.from(item));
      }
    }

    final proofsList = <Map<String, dynamic>>[];
    final rawProofs = row['proofs'];
    if (rawProofs is List) {
      for (final p in rawProofs) {
        if (p is Map) proofsList.add(Map<String, dynamic>.from(p));
      }
    } else if (rawProofs is String && rawProofs.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawProofs);
        if (decoded is List) {
          for (final p in decoded) {
            if (p is Map) proofsList.add(Map<String, dynamic>.from(p));
          }
        }
      } catch (_) {}
    }

    DateTime? winProofUploadedAt;
    if (row['win_proof_uploaded_at'] is String) {
      winProofUploadedAt = DateTime.tryParse(row['win_proof_uploaded_at']);
    }

    DateTime? completedAt;
    if (row['completed_at'] is String) {
      final parsed = DateTime.tryParse(row['completed_at']);
      if (parsed != null) {
        final nowUtc = DateTime.now().toUtc();
        if (parsed.isAfter(nowUtc)) {
          completedAt = DateTime(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute, parsed.second);
        } else {
          completedAt = parsed.toLocal();
        }
      }
    }

    DateTime? autoApproveAt;
    if (row['auto_approve_at'] is String) {
      autoApproveAt = DateTime.tryParse(row['auto_approve_at']);
    }
    DateTime? disputedAt;
    if (row['disputed_at'] is String) {
      disputedAt = DateTime.tryParse(row['disputed_at']);
    }
    DateTime? startTime;
    if (row['start_time'] is String) {
      startTime = DateTime.tryParse(row['start_time']);
    }

    return GamerRoom(
      id: (row['id'] ?? '').toString(),
      hostId: (row['host_id'] ?? '').toString(),
      game: (row['game'] ?? 'BGMI').toString(),
      mode: (row['mode'] ?? 'Erangel').toString(),
      roomId: (row['room_id'] ?? '').toString(),
      roomPassword: (row['room_password'] ?? '').toString(),
      prizePool: (row['prize_pool'] is num) ? (row['prize_pool'] as num).toInt() : 0,
      totalSlots: (row['total_slots'] is num) ? (row['total_slots'] as num).toInt() : 2,
      filledSlots: (row['filled_slots'] is num) ? (row['filled_slots'] as num).toInt() : 1,
      status: (row['status'] ?? 'active').toString(),
      createdAt: created,
      hostName: (row['host_name'] ?? 'Host').toString(),
      joinedUserIds: joinedUserIds,
      joinedUsers: joinedUsers,
      startTime: startTime ?? created,
      rewardStatus: (row['reward_status'] ?? 'idle').toString(),
      winnerId: row['winner_id']?.toString(),
      winnerName: row['winner_name']?.toString(),
      winProofUrl: row['win_proof_url']?.toString(),
      hostProofUrl: row['host_proof_url']?.toString(),
      opponentProofUrl: row['opponent_proof_url']?.toString(),
      proofs: proofsList,
      winProofUploadedAt: winProofUploadedAt,
      completedAt: completedAt,
      autoApproveAt: autoApproveAt,
      disputed: row['disputed'] == true,
      disputedBy: row['disputed_by']?.toString(),
      disputedByName: row['disputed_by_name']?.toString(),
      disputeReason: row['dispute_reason']?.toString(),
      disputedAt: disputedAt,
      entryFeeCoins: (row['entry_fee_coins'] is num) ? (row['entry_fee_coins'] as num).toInt() : 0,
    );
  }
}

class GamerRoomsScreen extends StatefulWidget {
  const GamerRoomsScreen({super.key});

  static Future<void> distributePrizeAndComplete({
    required GamerRoom room,
    required String winnerId,
    required String winnerName,
  }) async {
    final prize = room.prizePool;

    try {
      await CoinWalletService.updateCoins(
        userId: winnerId,
        amount: prize,
        type: 'win_prize',
        roomId: room.id,
        description: 'Tournament win prize: ${room.title}',
      );
    } catch (e) {
      debugPrint('Error updating winner coins: $e');
    }

    try {
      final winnerRow = await SupabaseService.client
          .from('users')
          .select('wins, total_winnings')
          .or('id.eq.$winnerId,uid.eq.$winnerId')
          .maybeSingle();
      if (winnerRow != null) {
        final currentWins = (winnerRow['wins'] as num?)?.toInt() ?? 0;
        final currentWinnings = (winnerRow['total_winnings'] as num?)?.toInt() ?? 0;
        await SupabaseService.client.from('users').update({
          'wins': currentWins + 1,
          'total_winnings': currentWinnings + prize,
        }).or('id.eq.$winnerId,uid.eq.$winnerId');
      }
    } catch (_) {}

    await SupabaseService.client.from('rooms').update({
      'reward_status': 'sent',
      'status': 'completed',
      'winner_id': winnerId,
      'winner_name': winnerName,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', room.id);

    try {
      await SupabaseService.client.from('messages').insert({
        'room_id': room.id,
        'sender_id': 'system',
        'sender_name': 'ROOM BOT',
        'message': '🏆 $winnerName won! +$prize coins',
        'type': 'system_reward',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}

    try {
      await NotificationService().sendNotification(
        userId: winnerId,
        type: 'match_result',
        title: '🏆 You won! +$prize coins',
        body: 'Congratulations $winnerName! You won ${room.title}.',
        data: {'room_id': room.id, 'prize': prize},
        priority: 'high',
      );
    } catch (_) {}
  }

  static Future<Map<String, String>?> getOrPromptGameProfile({
    required BuildContext context,
    required String gameName,
  }) async {
    final currentUser = SupabaseService.client.auth.currentUser;
    final meta = currentUser?.userMetadata ?? {};
    final gameProfiles = (meta['game_profiles'] is Map)
        ? Map<String, dynamic>.from(meta['game_profiles'])
        : <String, dynamic>{};

    final safeKey = gameName.trim().toLowerCase().replaceAll(' ', '_');

    if (gameProfiles[safeKey] is Map) {
      final existing = Map<String, dynamic>.from(gameProfiles[safeKey]);
      final ign = existing['ign']?.toString() ?? '';
      final uid = existing['game_uid']?.toString() ?? '';
      if (ign.isNotEmpty && uid.isNotEmpty) {
        return {'ign': ign, 'game_uid': uid};
      }
    }

    final rootIgn = meta['ign']?.toString() ?? meta['in_game_name']?.toString() ?? '';
    final rootUid = meta['game_uid']?.toString() ?? meta['character_id']?.toString() ?? '';
    if (rootIgn.isNotEmpty && rootUid.isNotEmpty) {
      return {'ign': rootIgn, 'game_uid': rootUid};
    }

    final ignController = TextEditingController(text: rootIgn);
    final uidController = TextEditingController(text: rootUid);

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.sports_esports_rounded, color: Color(0xFF1877F2), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'game_profile_title'.tr(args: [gameName]),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: ThemeService.textPrimary),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'game_profile_desc'.tr(args: [gameName]),
                style: TextStyle(fontSize: 12, color: ThemeService.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ignController,
                style: TextStyle(color: ThemeService.textPrimary),
                decoration: InputDecoration(
                  labelText: 'in_game_name_ign'.tr(),
                  labelStyle: TextStyle(color: ThemeService.textSecondary),
                  hintText: 'e.g. Sniper_King',
                  hintStyle: TextStyle(color: ThemeService.textSecondary.withOpacity(0.6)),
                  prefixIcon: Icon(Icons.badge_outlined, size: 20, color: ThemeService.textSecondary),
                  filled: true,
                  fillColor: ThemeService.cardSecondary,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: ThemeService.border),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: uidController,
                keyboardType: TextInputType.text,
                style: TextStyle(color: ThemeService.textPrimary),
                decoration: InputDecoration(
                  labelText: 'game_uid_label'.tr(),
                  labelStyle: TextStyle(color: ThemeService.textSecondary),
                  hintText: 'e.g. 5123456789',
                  hintStyle: TextStyle(color: ThemeService.textSecondary.withOpacity(0.6)),
                  prefixIcon: Icon(Icons.tag, size: 20, color: ThemeService.textSecondary),
                  filled: true,
                  fillColor: ThemeService.cardSecondary,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: ThemeService.border),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('btn_cancel'.tr(), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1877F2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final ign = ignController.text.trim();
              final uid = uidController.text.trim();
              if (ign.isEmpty || uid.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('enter_both_ign_uid'.tr())),
                );
                return;
              }

              gameProfiles[safeKey] = {'ign': ign, 'game_uid': uid};
              try {
                await SupabaseService.client.auth.updateUser(
                  UserAttributes(
                    data: {
                      ...meta,
                      'ign': ign,
                      'game_uid': uid,
                      'game_profiles': gameProfiles,
                    },
                  ),
                );
              } catch (e) {
                debugPrint('Error saving game profile: $e');
              }

              try {
                final currentUid = currentUser?.id;
                if (currentUid != null && currentUid.isNotEmpty) {
                  await SupabaseService.client.from('users').update({
                    'ign': ign,
                    'game_uid': uid,
                  }).or('id.eq.$currentUid,uid.eq.$currentUid');
                }
              } catch (_) {}

              if (ctx.mounted) {
                Navigator.pop(ctx, {'ign': ign, 'game_uid': uid});
              }
            },
            child: Text('save_and_continue'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    return result;
  }

  @override
  State<GamerRoomsScreen> createState() => _GamerRoomsScreenState();
}

class _GamerRoomsScreenState extends State<GamerRoomsScreen> {
  final GamerAuthService _authService = GamerAuthService();
  final CoinWalletService _walletService = CoinWalletService();
  Timer? _cleanupTimer;
  String _selectedCategory = 'All Games';

  static const List<String> _gameCategories = [
    'All Games',
    'BGMI',
    'Free Fire',
    'PUBG Mobile',
    'COD Mobile',
    'Valorant',
    'Ludo King',
    '8 Ball Pool',
  ];

  String get currentUserId =>
      _authService.currentGamer?.uid ??
      _authService.currentUid ??
      SupabaseService.client.auth.currentUser?.id ??
      'guest';

  String get currentUserName =>
      _authService.currentGamer?.displayName ??
      SupabaseService.client.auth.currentUser?.userMetadata?["full_name"]?.toString() ??
      'Gamer';

  String get currentUserPhoto =>
      _authService.currentGamer?.photoUrl ??
      SupabaseService.client.auth.currentUser?.userMetadata?["avatar_url"]?.toString() ??
      '';

  @override
  void initState() {
    super.initState();
    _walletService.getOrCreateWallet(currentUserId);
    _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _purgeExpiredCompletedRooms();
    });
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }

  Future<void> _purgeExpiredCompletedRooms() async {
    try {
      final now = DateTime.now();
      final rows = await SupabaseService.client
          .from('rooms')
          .select('id, completed_at, win_proof_uploaded_at, created_at')
          .eq('status', 'completed');

      for (final row in (rows as List)) {
        final rawComp = row['completed_at'] ?? row['win_proof_uploaded_at'] ?? row['created_at'];
        if (rawComp != null) {
          DateTime? completedAt = DateTime.tryParse(rawComp.toString());
          if (completedAt != null) {
            final localCompleted = completedAt.isUtc ? completedAt.toLocal() : completedAt;
            int elapsed = now.difference(localCompleted).inSeconds;
            if (elapsed < 0) {
              final reinterpreted = DateTime(
                completedAt.year,
                completedAt.month,
                completedAt.day,
                completedAt.hour,
                completedAt.minute,
                completedAt.second,
              );
              elapsed = now.difference(reinterpreted).inSeconds;
            }

            if (elapsed >= 300) {
              final roomId = row['id'];
              await SupabaseService.client.from('rooms').delete().eq('id', roomId);
              await SupabaseService.client.from('messages').delete().eq('room_id', roomId);
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _handleCreateRoomTap() async {
    if (currentUserId == 'guest') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('please_login_to_create_room'.tr())),
      );
      return;
    }

    await _purgeExpiredCompletedRooms();

    try {
      final response = await SupabaseService.client
          .from('rooms')
          .select('id, status, completed_at, win_proof_uploaded_at, created_at')
          .eq('host_id', currentUserId);

      int activeHostedRooms = 0;
      final now = DateTime.now();

      for (final r in (response as List)) {
        if (r['status'] == 'completed') {
          final rawComp = r['completed_at'] ?? r['win_proof_uploaded_at'] ?? r['created_at'];
          if (rawComp != null) {
            DateTime? comp = DateTime.tryParse(rawComp.toString());
            if (comp != null) {
              final localComp = comp.isUtc ? comp.toLocal() : comp;
              int elapsed = now.difference(localComp).inSeconds;
              if (elapsed < 0) {
                final reinterpreted = DateTime(comp.year, comp.month, comp.day, comp.hour, comp.minute, comp.second);
                elapsed = now.difference(reinterpreted).inSeconds;
              }
              if (elapsed >= 300) {
                try {
                  await SupabaseService.client.from('rooms').delete().eq('id', r['id']);
                  await SupabaseService.client.from('messages').delete().eq('room_id', r['id']);
                } catch (_) {}
                continue;
              }
            }
          }
        }
        activeHostedRooms++;
      }

      if (activeHostedRooms >= 2) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: ThemeService.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFFF4655), width: 1.5),
            ),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4655), size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'room_limit_reached'.tr(),
                    style: TextStyle(
                      color: ThemeService.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'room_limit_desc'.tr(),
              style: TextStyle(color: ThemeService.textSecondary, fontSize: 13, height: 1.4),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text('btn_ok'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        return;
      }

      if (mounted) {
        MatchRulesDialog.show(
          context,
          title: 'room_rules_title'.tr(),
          onProceed: () {
            if (mounted) _showCreateRoomDialog();
          },
        );
      }
    } catch (e) {
      debugPrint('Error checking active room limit: $e');
      if (mounted) {
        MatchRulesDialog.show(
          context,
          title: 'room_rules_title'.tr(),
          onProceed: () {
            if (mounted) _showCreateRoomDialog();
          },
        );
      }
    }
  }

  void _openRoomModal(GamerRoom room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RoomDetailsSheet(
        roomId: room.id,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        currentUserPhoto: currentUserPhoto,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;

        return Scaffold(
          backgroundColor: ThemeService.bg,
          appBar: AppBar(
            backgroundColor: ThemeService.appBarBg,
            elevation: 0.5,
            title: Text(
              'nav_rooms'.tr(),
              style: TextStyle(
                color: ThemeService.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF1877F2), size: 28),
                onPressed: _handleCreateRoomTap,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              Container(
                height: 48,
                color: ThemeService.card,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  itemCount: _gameCategories.length,
                  itemBuilder: (context, index) {
                    final cat = _gameCategories[index];
                    final isSelected = cat == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(cat == 'All Games' ? 'filter_all_games'.tr() : cat),
                        selected: isSelected,
                        selectedColor: const Color(0xFF1877F2),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : ThemeService.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        backgroundColor: ThemeService.cardSecondary,
                        onSelected: (val) {
                          if (val) setState(() => _selectedCategory = cat);
                        },
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SupabaseService.client
                      .from('rooms')
                      .stream(primaryKey: ['id'])
                      .order('created_at', ascending: false),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final list = snapshot.data ?? [];
                    final filtered = list.where((r) {
                      if (_selectedCategory == 'All Games') return true;
                      return (r['game'] ?? '').toString().toLowerCase() ==
                          _selectedCategory.toLowerCase();
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          'no_active_rooms'.tr(),
                          style: TextStyle(color: ThemeService.textSecondary),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final room = GamerRoom.fromSupabase(filtered[index]);

                        return Card(
                          color: ThemeService.card,
                          elevation: isDark ? 2 : 1,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: room.isCompleted ? const Color(0xFFFFD700) : ThemeService.border,
                              width: room.isCompleted ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              if (room.isCompleted) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Text('🏆', style: TextStyle(fontSize: 14)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'winner_badge_with_closing'.tr(args: [room.winnerName ?? 'champion'.tr()]),
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11.5,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              ListTile(
                                onTap: () => _openRoomModal(room),
                                leading: CircleAvatar(
                                  backgroundColor: room.isCompleted
                                      ? const Color(0xFFFFD700).withOpacity(0.2)
                                      : const Color(0xFF1877F2).withOpacity(0.15),
                                  child: Icon(
                                    room.isCompleted ? Icons.emoji_events_rounded : Icons.sports_esports,
                                    color: room.isCompleted ? const Color(0xFFFF8A00) : const Color(0xFF1877F2),
                                  ),
                                ),
                                title: Text(
                                  room.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: ThemeService.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  '${'host_label'.tr()}: ${room.hostName} • ${room.mode}',
                                  style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '🏆 ${room.prizePool} ${'coins_label'.tr()}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${room.filledSlots}/${room.totalSlots} ${'players_label'.tr()}',
                                      style: TextStyle(fontSize: 11, color: ThemeService.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
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

  void _showCreateRoomDialog() {
    final gameCtrl = TextEditingController(text: 'BGMI');
    final modeCtrl = TextEditingController(text: 'Erangel');
    final roomIdCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final prizeCtrl = TextEditingController(text: '100');
    bool isCreating = false;

    int selectedSlots = 2;
    String selectedFormat = '1 vs 1 (2 Slots)';
    final Map<String, int> formatOptions = {
      '1 vs 1 (2 Slots)': 2,
      '2 vs 2 (4 Slots)': 4,
      '4 vs 4 TDM (8 Slots)': 8,
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: ThemeService.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'create_game_room'.tr(),
            style: TextStyle(fontWeight: FontWeight.bold, color: ThemeService.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: gameCtrl,
                  style: TextStyle(color: ThemeService.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'game_label'.tr(),
                    labelStyle: TextStyle(color: ThemeService.textSecondary),
                  ),
                ),
                TextField(
                  controller: modeCtrl,
                  style: TextStyle(color: ThemeService.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'mode_map_label'.tr(),
                    labelStyle: TextStyle(color: ThemeService.textSecondary),
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: selectedFormat,
                  dropdownColor: ThemeService.card,
                  style: TextStyle(color: ThemeService.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'match_format_slots'.tr(),
                    labelStyle: TextStyle(color: ThemeService.textSecondary),
                  ),
                  items: formatOptions.keys.map((format) {
                    return DropdownMenuItem(
                      value: format,
                      child: Text(format, style: TextStyle(fontSize: 13, color: ThemeService.textPrimary)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedFormat = val;
                        selectedSlots = formatOptions[val]!;
                      });
                    }
                  },
                ),
                TextField(
                  controller: roomIdCtrl,
                  style: TextStyle(color: ThemeService.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'room_id_label'.tr(),
                    labelStyle: TextStyle(color: ThemeService.textSecondary),
                  ),
                ),
                TextField(
                  controller: passCtrl,
                  style: TextStyle(color: ThemeService.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'room_password_label'.tr(),
                    labelStyle: TextStyle(color: ThemeService.textSecondary),
                  ),
                ),
                TextField(
                  controller: prizeCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: ThemeService.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'prize_pool_coins_label'.tr(),
                    labelStyle: TextStyle(color: ThemeService.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isCreating ? null : () => Navigator.pop(ctx),
              child: Text('btn_cancel'.tr(), style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1877F2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isCreating
                  ? null
                  : () async {
                      final rId = roomIdCtrl.text.trim();
                      final pass = passCtrl.text.trim();
                      if (rId.isEmpty || pass.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('room_id_and_pass_required'.tr()),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isCreating = true);

                      try {
                        final currentRooms = await SupabaseService.client
                            .from('rooms')
                            .select('id')
                            .eq('host_id', currentUserId);
                        if ((currentRooms as List).length >= 2) {
                          setDialogState(() => isCreating = false);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('max_2_rooms_allowed'.tr()),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          return;
                        }

                        final gameName = gameCtrl.text.trim().isEmpty ? 'BGMI' : gameCtrl.text.trim();

                        String myIgn = currentUserName;
                        String myUid = currentUserId;

                        try {
                          final profile = await GamerRoomsScreen.getOrPromptGameProfile(
                            context: context,
                            gameName: gameName,
                          );
                          if (profile != null) {
                            if (profile['ign']?.isNotEmpty == true) myIgn = profile['ign']!;
                            if (profile['game_uid']?.isNotEmpty == true) myUid = profile['game_uid']!;
                          }
                        } catch (promptErr) {
                          debugPrint('[Rooms] Profile prompt notice: $promptErr');
                        }

                        final roomData = {
                          'game': gameName,
                          'mode': modeCtrl.text.trim().isEmpty ? 'Erangel' : modeCtrl.text.trim(),
                          'room_id': rId,
                          'room_password': pass,
                          'prize_pool': int.tryParse(prizeCtrl.text) ?? 100,
                          'total_slots': selectedSlots,
                          'filled_slots': 1,
                          'status': 'active',
                          'host_id': currentUserId,
                          'host_name': currentUserName,
                          'joined_user_ids': [currentUserId],
                          'joined_users': [
                            {
                              'id': currentUserId,
                              'name': currentUserName,
                              'avatar': currentUserPhoto,
                              'is_host': true,
                              'ign': myIgn,
                              'game_uid': myUid,
                            }
                          ],
                          'proofs': [],
                          'created_at': DateTime.now().toUtc().toIso8601String(),
                        };

                        await SupabaseService.client.from('rooms').insert(roomData);

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('room_created_success'.tr()),
                              backgroundColor: const Color(0xFF00FF88),
                            ),
                          );
                        }
                      } catch (e) {
                        debugPrint('[Rooms] Error creating room: $e');
                        setDialogState(() => isCreating = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${'room_creation_failed'.tr()}: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isCreating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('btn_create'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// IN-ROOM DETAILS & MANAGEMENT MODAL
// ═══════════════════════════════════════════════════════════════════════════════
class _RoomDetailsSheet extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserPhoto;

  const _RoomDetailsSheet({
    required this.roomId,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserPhoto,
  });

  @override
  State<_RoomDetailsSheet> createState() => _RoomDetailsSheetState();
}

class _RoomDetailsSheetState extends State<_RoomDetailsSheet> {
  final TextEditingController _msgController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  Timer? _countdownTimer;
  int _secondsRemaining = 300;
  bool _isUploadingProof = false;
  bool _isJoining = false;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _msgController.dispose();
    super.dispose();
  }

  void _showRulesDialog() {
    MatchRulesDialog.show(
      context,
      title: 'tournament_rules_title'.tr(),
      onProceed: () {},
    );
  }

  void _start5MinCountdown(DateTime completedAt) {
    _countdownTimer?.cancel();

    final now = DateTime.now();
    final localCompleted = completedAt.isUtc ? completedAt.toLocal() : completedAt;

    int elapsed = now.difference(localCompleted).inSeconds;
    if (elapsed < 0) {
      final reinterpreted = DateTime(
        completedAt.year,
        completedAt.month,
        completedAt.day,
        completedAt.hour,
        completedAt.minute,
        completedAt.second,
      );
      elapsed = now.difference(reinterpreted).inSeconds;
    }
    if (elapsed < 0) elapsed = 0;

    _secondsRemaining = (300 - elapsed).clamp(0, 300);

    if (_secondsRemaining <= 0) {
      Future.microtask(() async {
        try {
          await SupabaseService.client.from('rooms').delete().eq('id', widget.roomId);
          await SupabaseService.client.from('messages').delete().eq('room_id', widget.roomId);
        } catch (_) {}
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('match_ended_room_deleted'.tr())),
          );
        }
      });
      return;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        try {
          await SupabaseService.client.from('rooms').delete().eq('id', widget.roomId);
          await SupabaseService.client.from('messages').delete().eq('room_id', widget.roomId);
        } catch (_) {}
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('match_ended_room_deleted'.tr())),
          );
        }
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _joinMatch(GamerRoom room) async {
    if (_isJoining) return;
    if (room.isFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('room_already_full'.tr())),
      );
      return;
    }

    setState(() => _isJoining = true);

    try {
      final profile = await GamerRoomsScreen.getOrPromptGameProfile(
        context: context,
        gameName: room.game,
      );

      if (profile == null) {
        setState(() => _isJoining = false);
        return;
      }

      final myIgn = profile['ign'] ?? widget.currentUserName;
      final myUid = profile['game_uid'] ?? '';

      final updatedIds = [...room.joinedUserIds, widget.currentUserId];
      final updatedUsers = [
        ...room.joinedUsers,
        {
          'id': widget.currentUserId,
          'name': widget.currentUserName,
          'avatar': widget.currentUserPhoto,
          'is_host': false,
          'ign': myIgn,
          'game_uid': myUid,
        }
      ];

      await SupabaseService.client.from('rooms').update({
        'joined_user_ids': updatedIds,
        'joined_users': updatedUsers,
        'filled_slots': updatedUsers.length,
      }).eq('id', widget.roomId);

      await SupabaseService.client.from('messages').insert({
        'room_id': widget.roomId,
        'sender_id': 'system',
        'sender_name': 'ROOM BOT',
        'message': '👋 ${widget.currentUserName} ($myIgn) joined the match!',
        'type': 'system',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('joined_room_success'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'join_room_error'.tr()}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  /// ✅ MULTI-PROOF UPLOAD: Pehle wale ka proof overwrite hone se bachata hai
  Future<void> _uploadWinScreenshot() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;

    setState(() => _isUploadingProof = true);

    try {
      final bytes = await file.readAsBytes();
      final ext = file.path.split('.').last;
      final fileName = 'proof_${widget.roomId}_${widget.currentUserId}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await SupabaseService.client.storage
          .from('match_proofs')
          .uploadBinary(fileName, bytes);

      final proofUrl = SupabaseService.client.storage
          .from('match_proofs')
          .getPublicUrl(fileName);

      // 1. Current room data fetch karein taake existing proofs array mil sake
      final currentRoomRow = await SupabaseService.client
          .from('rooms')
          .select('host_id, proofs, host_proof_url, opponent_proof_url')
          .eq('id', widget.roomId)
          .maybeSingle();

      final hostId = (currentRoomRow?['host_id'] ?? '').toString();
      final bool isHost = widget.currentUserId == hostId;

      List<dynamic> existingProofs = [];
      final rawProofs = currentRoomRow?['proofs'];
      if (rawProofs is List) {
        existingProofs = List.from(rawProofs);
      } else if (rawProofs is String && rawProofs.isNotEmpty) {
        try {
          final dec = jsonDecode(rawProofs);
          if (dec is List) existingProofs = List.from(dec);
        } catch (_) {}
      }

      // Is user ka proof list mein add ya update karein
      existingProofs.removeWhere((p) => (p is Map && p['user_id']?.toString() == widget.currentUserId));
      existingProofs.add({
        'user_id': widget.currentUserId,
        'user_name': widget.currentUserName,
        'avatar': widget.currentUserPhoto,
        'is_host': isHost,
        'proof_url': proofUrl,
        'uploaded_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Status check: Agar dono parties ne claim kar diya hai to disputed / multi-claim ban jaye
      final bool hasMultipleClaims = existingProofs.length > 1;
      final String nextStatus = hasMultipleClaims ? 'disputed' : 'review_pending';

      final Map<String, dynamic> updateData = {
        'status': nextStatus,
        'reward_status': 'pending_approval',
        'winner_id': widget.currentUserId,
        'winner_name': widget.currentUserName,
        'win_proof_url': proofUrl,
        'win_proof_uploaded_at': DateTime.now().toUtc().toIso8601String(),
        'proofs': existingProofs,
      };

      if (isHost) {
        updateData['host_proof_url'] = proofUrl;
      } else {
        updateData['opponent_proof_url'] = proofUrl;
      }

      if (hasMultipleClaims) {
        updateData['disputed'] = true;
        updateData['dispute_reason'] = 'Both players claimed win. Admin verification required.';
        updateData['disputed_at'] = DateTime.now().toUtc().toIso8601String();
      }

      await SupabaseService.client.from('rooms').update(updateData).eq('id', widget.roomId);

      await SupabaseService.client.from('messages').insert({
        'room_id': widget.roomId,
        'sender_id': 'system',
        'sender_name': 'ROOM BOT',
        'message': '📸 ${widget.currentUserName} uploaded win proof! Waiting for admin review.',
        'type': 'system',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('proof_uploaded_success'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'upload_failed'.tr()}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingProof = false);
    }
  }

  Future<void> _raiseDisputeDialog() async {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        title: Text('raise_dispute_title'.tr(), style: TextStyle(color: ThemeService.textPrimary)),
        content: TextField(
          controller: reasonCtrl,
          style: TextStyle(color: ThemeService.textPrimary),
          decoration: InputDecoration(
            hintText: 'dispute_reason_hint'.tr(),
            hintStyle: TextStyle(color: ThemeService.textSecondary),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('btn_cancel'.tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);

              await SupabaseService.client.from('rooms').update({
                'disputed': true,
                'status': 'disputed',
                'disputed_by': widget.currentUserId,
                'disputed_by_name': widget.currentUserName,
                'dispute_reason': reason,
                'disputed_at': DateTime.now().toUtc().toIso8601String(),
              }).eq('id', widget.roomId);

              await SupabaseService.client.from('messages').insert({
                'room_id': widget.roomId,
                'sender_id': 'system',
                'sender_name': 'DISPUTE BOT',
                'message': '⚠️ Dispute raised by ${widget.currentUserName}: "$reason". Admin will review.',
                'type': 'system_dispute',
                'created_at': DateTime.now().toUtc().toIso8601String(),
              });
            },
            child: Text('submit_dispute'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final txt = _msgController.text.trim();
    if (txt.isEmpty) return;
    _msgController.clear();

    await SupabaseService.client.from('messages').insert({
      'room_id': widget.roomId,
      'sender_id': widget.currentUserId,
      'sender_name': widget.currentUserName,
      'message': txt,
      'type': 'chat',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.isDarkMode;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SupabaseService.client
            .from('rooms')
            .stream(primaryKey: ['id'])
            .eq('id', widget.roomId),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final room = GamerRoom.fromSupabase(snapshot.data!.first);
          final bool isJoined = room.joinedUserIds.contains(widget.currentUserId);

          if (room.isCompleted && _countdownTimer == null) {
            final compTime = room.completedAt ?? room.winProofUploadedAt ?? room.createdAt;
            _start5MinCountdown(compTime);
          }

          final mins = _secondsRemaining ~/ 60;
          final secs = _secondsRemaining % 60;
          final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

          return Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ThemeService.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: ThemeService.textPrimary,
                          ),
                        ),
                        Text(
                          '${'host_label'.tr()}: ${room.hostName} • ${room.mode}',
                          style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: ThemeService.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: ThemeService.border),

              if (room.isCompleted) ...[
                Builder(builder: (context) {
                  final opponents = room.joinedUsers
                      .where((u) => (u['id'] ?? '').toString() != (room.winnerId ?? ''))
                      .map((u) {
                        final ign = u['ign']?.toString() ?? '';
                        final name = u['name']?.toString() ?? 'players_label'.tr();
                        return ign.isNotEmpty ? '$name ($ign)' : name;
                      })
                      .toList();
                  final vsText = opponents.isNotEmpty ? opponents.join(', ') : 'opponent_team'.tr();

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Text('🏆', style: TextStyle(fontSize: 34)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${'winner_label'.tr()}: ${room.winnerName ?? "champion".tr()}!',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '⚔️ ${'defeated_label'.tr()}: $vsText',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${'prize_pool_label'.tr()}: ${room.prizePool} ${'coins_label'.tr()} • ${'closes_in_label'.tr()}: $timeStr',
                                style: TextStyle(
                                  color: Colors.black.withOpacity(0.75),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ] else if (room.isDisputed) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'match_disputed_banner'.tr(),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (room.disputeReason != null)
                        Text(
                          '${'reason_label'.tr()}: ${room.disputeReason}',
                          style: TextStyle(color: ThemeService.textPrimary, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ] else if (room.isRejected) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'proof_rejected_reupload'.tr(),
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (room.isProofSubmitted) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_top, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'proof_under_review_banner'.tr(),
                          style: const TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1917) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.key, color: Colors.amber, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'room_credentials_label'.tr(),
                              style: TextStyle(
                                color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: _showRulesDialog,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Text('📜 ', style: TextStyle(fontSize: 11)),
                                Text(
                                  'rules_button'.tr(),
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${'room_id_label'.tr()}\n${room.roomId}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: ThemeService.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18, color: Color(0xFF1877F2)),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: room.roomId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('copied_room_id'.tr())),
                            );
                          },
                        ),
                      ],
                    ),
                    Divider(height: 8, color: isDark ? const Color(0xFF442A0D) : const Color(0xFFFDE68A)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${'room_password_label'.tr()}\n${room.roomPassword}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: ThemeService.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18, color: Color(0xFF1877F2)),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: room.roomPassword));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('copied_room_password'.tr())),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ThemeService.cardSecondary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ThemeService.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.group, size: 16, color: Color(0xFF1877F2)),
                        const SizedBox(width: 6),
                        Text(
                          '${'players_label'.tr()} (${room.joinedUsers.length}/${room.totalSlots})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: ThemeService.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...room.joinedUsers.map((user) {
                      final uId = (user['id'] ?? '').toString();
                      final uName = (user['name'] ?? 'players_label'.tr()).toString();
                      final uAvatar = (user['avatar'] ?? '').toString();
                      final ign = user['ign']?.toString() ?? user['in_game_name']?.toString();
                      final gameUid = user['game_uid']?.toString() ?? user['character_id']?.toString();
                      final isHost = uId == room.hostId;
                      final isMe = uId == widget.currentUserId;

                      final isWinner = room.isCompleted &&
                          (uId == room.winnerId || (room.winnerName != null && uName == room.winnerName));
                      final isLoser = room.isCompleted && !isWinner;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            GamerAvatar(
                              photoUrl: uAvatar,
                              displayName: uName,
                              radius: 16,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          uName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: ThemeService.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isWinner) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFB300),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text('winner_badge'.tr(),
                                              style: const TextStyle(
                                                  color: Colors.black87,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ] else if (isLoser) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.18),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.red, width: 0.8),
                                          ),
                                          child: Text('defeated_badge'.tr(),
                                              style: const TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ] else if (isHost) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text('host_badge'.tr(),
                                              style: const TextStyle(
                                                  color: Colors.blue,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                      if (isMe) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text('you_badge'.tr(),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        (ign != null && ign.isNotEmpty) ? 'IGN: $ign' : 'IGN: $uName',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: ThemeService.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (gameUid != null && gameUid.isNotEmpty) ...[
                                        Text(
                                          ' • ID: $gameUid',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: ThemeService.textSecondary.withOpacity(0.8),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () {
                                            Clipboard.setData(ClipboardData(text: gameUid));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('${'game_uid_copied'.tr()}: $gameUid'),
                                                duration: const Duration(seconds: 1),
                                              ),
                                            );
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.only(left: 4),
                                            child: Icon(Icons.copy, size: 12, color: Color(0xFF1877F2)),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),

              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SupabaseService.client
                      .from('messages')
                      .stream(primaryKey: ['id'])
                      .eq('room_id', widget.roomId)
                      .order('created_at', ascending: true),
                  builder: (context, msgSnap) {
                    final msgs = msgSnap.data ?? [];
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      itemCount: msgs.length,
                      itemBuilder: (context, idx) {
                        final m = msgs[idx];
                        final isSys = m['type'] != 'chat';
                        final sender = m['sender_name'] ?? 'players_label'.tr();
                        final txt = m['message'] ?? '';

                        if (isSys) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ThemeService.cardSecondary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              txt,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }

                        final isMe = m['sender_id'] == widget.currentUserId;
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isMe ? const Color(0xFF1877F2) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE4E6EB)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (!isMe)
                                  Text(
                                    sender,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                      color: isDark ? const Color(0xFF94A3B8) : Colors.black54,
                                    ),
                                  ),
                                Text(
                                  txt,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        style: TextStyle(color: ThemeService.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'type_message_hint'.tr(),
                          hintStyle: TextStyle(color: ThemeService.textSecondary),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          filled: true,
                          fillColor: ThemeService.cardSecondary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFF1877F2)),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),

              if (!room.isCompleted) ...[
                if (!isJoined) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 2,
                        ),
                        icon: _isJoining
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.login, size: 20),
                        label: Text(
                          _isJoining
                              ? 'joining_label'.tr()
                              : '${'join_match_button'.tr()} (${room.filledSlots}/${room.totalSlots})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onPressed: _isJoining
                            ? null
                            : () {
                                MatchRulesDialog.show(
                                  context,
                                  title: '${'match_rules_title'.tr()} (${room.title})',
                                  onProceed: () => _joinMatch(room),
                                );
                              },
                      ),
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: room.isRejected
                                  ? const Color(0xFFFF4655)
                                  : (room.isProofSubmitted
                                      ? const Color(0xFF1877F2)
                                      : Colors.amber[700]),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: _isUploadingProof
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Icon(
                                    room.isRejected
                                        ? Icons.refresh_rounded
                                        : (room.isProofSubmitted
                                            ? Icons.hourglass_top_rounded
                                            : Icons.emoji_events),
                                    size: 18,
                                  ),
                            label: Text(
                              _isUploadingProof
                                  ? 'uploading_label'.tr()
                                  : (room.isRejected
                                      ? 'reupload_proof_button'.tr()
                                      : (room.isProofSubmitted
                                          ? 'proof_submitted_tap_to_change'.tr()
                                          : 'end_match_claim_win'.tr())),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            onPressed: _isUploadingProof ? null : _uploadWinScreenshot,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (!room.isDisputed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextButton.icon(
                        icon: const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.grey),
                        label: Text('raise_dispute_button'.tr(),
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        onPressed: _raiseDisputeDialog,
                      ),
                    ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}
