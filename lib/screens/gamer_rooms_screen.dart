// ═══════════════════════════════════════════════════════════════════════════════
// COMPLETE GAMER ROOMS SCREEN
// - Realtime Joined Players List with Avatars, Names, IGN & Game UID
// - 1-Time Game ID & IGN Auto-Save Popup (Multi-Game Ready)
// - Join Match Button for non-host players with slot reservation
// - Esports Match Rules & Guidelines Dialog
// - Flexible Match Formats (1v1, 2v2, 4v4 TDM)
// - "End Match / Claim Win" Screenshot Proof Upload to Supabase Storage
// - 5-Minute Golden Winner Banner with Live Countdown Timer
// - Auto-delete room after 5 minutes of completion
// - Dispute management & Admin approval flow
// ═══════════════════════════════════════════════════════════════════════════════
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
import '../widgets/gamer_avatar.dart';

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
  bool get isProofSubmitted =>
      !isCompleted &&
      (status.toLowerCase() == 'proof_submitted' ||
          status.toLowerCase() == 'review_pending' ||
          (winProofUrl != null && winProofUrl!.isNotEmpty));

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

    DateTime? winProofUploadedAt;
    if (row['win_proof_uploaded_at'] is String) {
      winProofUploadedAt = DateTime.tryParse(row['win_proof_uploaded_at']);
    }
    DateTime? completedAt;
    if (row['completed_at'] is String) {
      completedAt = DateTime.tryParse(row['completed_at']);
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

  /// Prize Distribution & Room Completion Trigger
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
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', room.id);

    try {
      await SupabaseService.client.from('messages').insert({
        'room_id': room.id,
        'sender_id': 'system',
        'sender_name': 'ROOM BOT',
        'message': '🏆 $winnerName won! +$prize coins',
        'type': 'system_reward',
        'created_at': DateTime.now().toIso8601String(),
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

  /// HELPER: 1-Time Game Profile Prompt & Auto-Save
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

    // Check if profile already exists
    if (gameProfiles[safeKey] is Map) {
      final existing = Map<String, dynamic>.from(gameProfiles[safeKey]);
      final ign = existing['ign']?.toString() ?? '';
      final uid = existing['game_uid']?.toString() ?? '';
      if (ign.isNotEmpty && uid.isNotEmpty) {
        return {'ign': ign, 'game_uid': uid};
      }
    }

    // Check root metadata fallback
    final rootIgn = meta['ign']?.toString() ?? meta['in_game_name']?.toString() ?? '';
    final rootUid = meta['game_uid']?.toString() ?? meta['character_id']?.toString() ?? '';
    if (rootIgn.isNotEmpty && rootUid.isNotEmpty) {
      return {'ign': rootIgn, 'game_uid': rootUid};
    }

    // Prompt user via clean esports dialog
    final ignController = TextEditingController(text: rootIgn);
    final uidController = TextEditingController(text: rootUid);

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.sports_esports_rounded, color: Color(0xFF1877F2), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$gameName ID Details',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1E293B)),
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
                'Enter your official $gameName details. This will be automatically saved for all future $gameName matches.',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ignController,
                decoration: InputDecoration(
                  labelText: 'In-Game Name (IGN)',
                  hintText: 'e.g. Sniper_King',
                  prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: uidController,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: 'Character ID / Game UID',
                  hintText: 'e.g. 5123456789',
                  prefixIcon: const Icon(Icons.tag, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
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
                  const SnackBar(content: Text('Please fill both In-Game Name & UID')),
                );
                return;
              }

              // Auto-Save to Supabase User Metadata permanently
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

              // Update users table in database as well
              try {
                final currentUid = currentUser?.id;
                if (currentUid != null && currentUid.isNotEmpty) {
                  await SupabaseService.client.from('users').update({
                    'ign': ign,
                    'game_uid': uid,
                  }).or('id.eq.$currentUid,uid.eq.$currentUid');
                }
              } catch (_) {}

              Navigator.pop(ctx, {'ign': ign, 'game_uid': uid});
            },
            child: const Text('Save & Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  /// FEATURE 4: 5 Minutes baad Completed Room ko Supabase se Auto Delete karna
  Future<void> _purgeExpiredCompletedRooms() async {
    try {
      final now = DateTime.now();
      final rows = await SupabaseService.client
          .from('rooms')
          .select('id, completed_at')
          .eq('status', 'completed');

      for (final row in (rows as List)) {
        if (row['completed_at'] != null) {
          final completedAt = DateTime.tryParse(row['completed_at'].toString());
          if (completedAt != null && now.difference(completedAt).inSeconds >= 300) {
            final roomId = row['id'];
            await SupabaseService.client.from('rooms').delete().eq('id', roomId);
            await SupabaseService.client.from('messages').delete().eq('room_id', roomId);
          }
        }
      }
    } catch (_) {}
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
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Rooms',
          style: TextStyle(
            color: Color(0xFF050505),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF1877F2), size: 28),
            onPressed: () => _showCreateRoomDialog(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Game Categories
          Container(
            height: 48,
            color: Colors.white,
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
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: const Color(0xFF1877F2),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    backgroundColor: const Color(0xFFF0F2F5),
                    onSelected: (val) {
                      if (val) setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              },
            ),
          ),

          // Realtime Rooms List
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
                  return const Center(
                    child: Text('No active rooms found. Tap + to create one!',
                        style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final room = GamerRoom.fromSupabase(filtered[index]);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        onTap: () => _openRoomModal(room),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1877F2).withOpacity(0.1),
                          child: const Icon(Icons.sports_esports, color: Color(0xFF1877F2)),
                        ),
                        title: Text(room.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Host: ${room.hostName} • ${room.mode}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('🏆 ${room.prizePool} Coins',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, color: Colors.orange)),
                            const SizedBox(height: 4),
                            Text('${room.filledSlots}/${room.totalSlots} Players',
                                style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
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
  }

  void _showCreateRoomDialog() {
    final gameCtrl = TextEditingController(text: 'BGMI');
    final modeCtrl = TextEditingController(text: 'Erangel');
    final roomIdCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final prizeCtrl = TextEditingController(text: '100');

    // Esports Flexible Match Formats
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
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Game Room', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: gameCtrl, decoration: const InputDecoration(labelText: 'Game')),
                TextField(controller: modeCtrl, decoration: const InputDecoration(labelText: 'Map / Mode')),
                DropdownButtonFormField<String>(
                  value: selectedFormat,
                  decoration: const InputDecoration(labelText: 'Match Format / Slots'),
                  items: formatOptions.keys.map((format) {
                    return DropdownMenuItem(
                      value: format,
                      child: Text(format, style: const TextStyle(fontSize: 13)),
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
                TextField(controller: roomIdCtrl, decoration: const InputDecoration(labelText: 'Room ID')),
                TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password')),
                TextField(
                  controller: prizeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Prize Pool (Coins)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1877F2)),
              onPressed: () async {
                if (roomIdCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) return;
                final gameName = gameCtrl.text.trim();

                // 1-Time check / prompt for host game profile
                final profile = await GamerRoomsScreen.getOrPromptGameProfile(
                  context: context,
                  gameName: gameName,
                );
                if (profile == null) return;

                final myIgn = profile['ign'] ?? currentUserName;
                final myUid = profile['game_uid'] ?? '';

                final roomData = {
                  'game': gameName,
                  'mode': modeCtrl.text.trim(),
                  'room_id': roomIdCtrl.text.trim(),
                  'room_password': passCtrl.text.trim(),
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
                  'created_at': DateTime.now().toIso8601String(),
                };

                if (mounted) Navigator.pop(ctx);
                await SupabaseService.client.from('rooms').insert(roomData);
              },
              child: const Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// IN-ROOM DETAILS & MANAGEMENT MODAL (Matches 1000064588.png)
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Text('📜 ', style: TextStyle(fontSize: 20)),
            Text('Tournament Rules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B))),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _RuleItem(icon: Icons.phone_android, title: 'Mobile Only', desc: 'Emulators, PC, and iPad view modifications are strictly prohibited.'),
              SizedBox(height: 10),
              _RuleItem(icon: Icons.security, title: 'Fair Play', desc: 'Hacks, scripts, and third-party GFX tools will lead to permanent account ban.'),
              SizedBox(height: 10),
              _RuleItem(icon: Icons.camera_alt, title: 'Mandatory Proof', desc: 'End-game screenshot showing kills & rank is mandatory to claim prize.'),
              SizedBox(height: 10),
              _RuleItem(icon: Icons.group_off, title: 'No Teaming', desc: 'Teaming with opponents or griefing will forfeit match and coins.'),
              SizedBox(height: 10),
              _RuleItem(icon: Icons.gavel, title: 'Admin Authority', desc: 'In case of dispute, Admin verification based on submitted proof is final.'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1877F2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('I Understand', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _start5MinCountdown(DateTime completedAt) {
    _countdownTimer?.cancel();
    final elapsed = DateTime.now().difference(completedAt).inSeconds;
    _secondsRemaining = (300 - elapsed).clamp(0, 300);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        // 5 Minutes finish -> Auto Delete Room & pop
        try {
          await SupabaseService.client.from('rooms').delete().eq('id', widget.roomId);
          await SupabaseService.client.from('messages').delete().eq('room_id', widget.roomId);
        } catch (_) {}
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Match finished. Room auto-deleted.')),
          );
        }
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  /// FEATURE: Join Match with 1-Time Game Profile Check
  Future<void> _joinMatch(GamerRoom room) async {
    if (_isJoining) return;
    if (room.isFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room is already full!')),
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
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Successfully joined room!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining room: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  /// FEATURE 2: Upload Winning Screenshot
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
      final fileName = 'proof_${widget.roomId}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      // 1. Upload to Supabase Storage Bucket 'match_proofs'
      await SupabaseService.client.storage
          .from('match_proofs')
          .uploadBinary(fileName, bytes);

      final proofUrl = SupabaseService.client.storage
          .from('match_proofs')
          .getPublicUrl(fileName);

      // 2. Update Room Status to 'review_pending'
      await SupabaseService.client.from('rooms').update({
        'status': 'review_pending',
        'reward_status': 'pending_approval',
        'winner_id': widget.currentUserId,
        'winner_name': widget.currentUserName,
        'win_proof_url': proofUrl,
        'win_proof_uploaded_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.roomId);

      // 3. System chat notification
      await SupabaseService.client.from('messages').insert({
        'room_id': widget.roomId,
        'sender_id': 'system',
        'sender_name': 'ROOM BOT',
        'message': '📸 ${widget.currentUserName} uploaded win proof! Waiting for admin approval.',
        'type': 'system',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Screenshot submitted! Admin will verify soon.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingProof = false);
    }
  }

  /// Raise Dispute Dialog
  Future<void> _raiseDisputeDialog() async {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Raise Dispute / Report Issue'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(hintText: 'Enter reason for dispute...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
                'disputed_at': DateTime.now().toIso8601String(),
              }).eq('id', widget.roomId);

              await SupabaseService.client.from('messages').insert({
                'room_id': widget.roomId,
                'sender_id': 'system',
                'sender_name': 'DISPUTE BOT',
                'message': '⚠️ Dispute raised by ${widget.currentUserName}: "$reason". Admin will review.',
                'type': 'system_dispute',
                'created_at': DateTime.now().toIso8601String(),
              });
            },
            child: const Text('Submit Dispute', style: TextStyle(color: Colors.white)),
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
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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

          if (room.isCompleted && room.completedAt != null && _countdownTimer == null) {
            _start5MinCountdown(room.completedAt!);
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
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: ChangeHorizontal(16, 8),
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          'Host: ${room.hostName} • ${room.mode}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // BANNERS: Winner / Disputed / Under Review
              if (room.isCompleted) ...[
                // FEATURE 3 & 4: 5-Minute Golden Winner Banner
                Container(
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
                      const Text('🏆', style: TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WINNER: ${room.winnerName ?? "Champion"}!',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Prize: ${room.prizePool} Coins • Room closes in: $timeStr',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
                      const Text(
                        '⚠️ MATCH DISPUTED — ESCALATED TO ADMIN',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (room.disputeReason != null)
                        Text(
                          'Reason: ${room.disputeReason}',
                          style: const TextStyle(color: Colors.black87, fontSize: 12),
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
                  child: const Row(
                    children: [
                      Icon(Icons.hourglass_top, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Match Finished! Winner proof under admin review ⏳',
                          style: TextStyle(
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

              // ROOM CREDENTIALS + RULES BUTTON
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.key, color: Colors.amber, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'ROOM CREDENTIALS',
                              style: TextStyle(
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        // 📜 RULES MODAL BUTTON
                        InkWell(
                          onTap: _showRulesDialog,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Text('📜 ', style: TextStyle(fontSize: 11)),
                                Text(
                                  'Rules',
                                  style: TextStyle(
                                    color: Color(0xFF92400E),
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
                        Text('ROOM ID\n${room.roomId}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18, color: Color(0xFF1877F2)),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: room.roomId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Room ID copied!')),
                            );
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('PASSWORD\n${room.roomPassword}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18, color: Color(0xFF1877F2)),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: room.roomPassword));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password copied!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // FEATURE 1: PLAYERS LIST
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.group, size: 16, color: Color(0xFF1877F2)),
                        const SizedBox(width: 6),
                        Text(
                          'PLAYERS (${room.joinedUsers.length}/${room.totalSlots})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...room.joinedUsers.map((user) {
                      final uId = (user['id'] ?? '').toString();
                      final uName = (user['name'] ?? 'Player').toString();
                      final uAvatar = (user['avatar'] ?? '').toString();
                      final ign = user['ign']?.toString() ?? user['in_game_name']?.toString();
                      final gameUid = user['game_uid']?.toString() ?? user['character_id']?.toString();
                      final isHost = uId == room.hostId;
                      final isMe = uId == widget.currentUserId;

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
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isHost) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('HOST',
                                              style: TextStyle(
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
                                          child: const Text('YOU',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  // In-Game Name & Character ID with copy button
                                  Row(
                                    children: [
                                      Text(
                                        (ign != null && ign.isNotEmpty) ? 'IGN: $ign' : 'IGN: $uName',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (gameUid != null && gameUid.isNotEmpty) ...[
                                        Text(
                                          ' • ID: $gameUid',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () {
                                            Clipboard.setData(ClipboardData(text: gameUid));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Copied Game UID: $gameUid'),
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

              // CHAT MESSAGES STREAM
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
                        final sender = m['sender_name'] ?? 'Player';
                        final txt = m['message'] ?? '';

                        if (isSys) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(txt,
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.blueGrey,
                                    fontWeight: FontWeight.bold)),
                          );
                        }

                        final isMe = m['sender_id'] == widget.currentUserId;
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isMe ? const Color(0xFF1877F2) : const Color(0xFFE4E6EB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (!isMe)
                                  Text(sender,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                          color: Colors.black54)),
                                Text(txt,
                                    style: TextStyle(
                                        color: isMe ? Colors.white : Colors.black87, fontSize: 13)),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // CHAT INPUT
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          filled: true,
                          fillColor: const Color(0xFFF0F2F5),
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

              // ACTION BUTTONS: Join Match OR End Match & Dispute
              if (!room.isCompleted) ...[
                if (!isJoined) ...[
                  // JOIN MATCH BUTTON (For new players)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                          _isJoining ? 'Joining Match...' : 'JOIN MATCH (${room.filledSlots}/${room.totalSlots})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onPressed: _isJoining ? null : () => _joinMatch(room),
                      ),
                    ),
                  ),
                ] else ...[
                  // FEATURE 2: End Match & Upload Win Proof Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber[700],
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
                                : const Icon(Icons.emoji_events, size: 18),
                            label: Text(
                              _isUploadingProof
                                  ? 'Uploading...'
                                  : (room.isProofSubmitted
                                      ? 'Re-upload Proof'
                                      : 'End Match (I Won)'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            onPressed: _isUploadingProof ? null : _uploadWinScreenshot,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Dispute Button
                  if (!room.isDisputed)
                    TextButton.icon(
                      icon: const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.grey),
                      label: const Text('Raise Dispute / Report Issue',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      onPressed: _raiseDisputeDialog,
                    ),
                ],
              ],

              // LEAVE ROOM BUTTON
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('LEAVE ROOM',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  MainAxisAlignment ChangeHorizontal(double left, double right) => MainAxisAlignment.spaceBetween;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER: RULES MODAL ITEM
// ═══════════════════════════════════════════════════════════════════════════════
class _RuleItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _RuleItem({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF1877F2), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
              const SizedBox(height: 2),
              Text(desc, style: TextStyle(fontSize: 11.5, color: Colors.grey[700])),
            ],
          ),
        ),
      ],
    );
  }
}
