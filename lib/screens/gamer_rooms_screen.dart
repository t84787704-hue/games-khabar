import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../constants/gamer_theme.dart';
import '../services/gamer_auth_service.dart';
import '../services/tournament_service.dart';
import '../services/coin_wallet_service.dart';
import '../services/ad_free_service.dart';
import '../services/supabase_service.dart';
import '../services/win_proof_validator.dart';
import 'coin_store_screen.dart';
import '../widgets/coin_history_sheet.dart';

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
  final String ocrStatus;
  final String ocrText;
  final int ocrScore;
  final String? proofUrl;
  final String? winProofUrl;
  final DateTime? winProofUploadedAt;
  final DateTime? completedAt;
  final DateTime? autoApproveAt;
  final bool disputed;
  final String? disputedBy;
  final String? disputedByName;
  final String? disputeReason;
  final String? disputeProofUrl;
  final DateTime? disputedAt;

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
    this.ocrStatus = 'none',
    this.ocrText = '',
    this.ocrScore = 0,
    this.proofUrl,
    this.winProofUrl,
    this.winProofUploadedAt,
    this.completedAt,
    this.autoApproveAt,
    this.disputed = false,
    this.disputedBy,
    this.disputedByName,
    this.disputeReason,
    this.disputeProofUrl,
    this.disputedAt,
  }) : startTime = startTime ?? createdAt;

  String get title => '$game $mode';
  String get map => mode;
  int get prize => prizePool;
  int get total => totalSlots;
  int get filled => filledSlots;
  String get roomIdCode => roomId;
  String get password => roomPassword;
  String get entryFee => 'FREE';
  String get prizeSource => 'application';

  bool get isFull => filledSlots >= totalSlots;
  bool get isCompleted =>
      status.toLowerCase() == 'completed' ||
      rewardStatus.toLowerCase() == 'sent';
  bool get isDisputed =>
      disputed ||
      status.toLowerCase() == 'disputed' ||
      status.toLowerCase() == 'under_review';
  bool get isUnderReview =>
      status.toLowerCase() == 'under_review' || isDisputed;
  bool get isProofRejected {
    if (isCompleted) return false;
    final st = status.toLowerCase();
    final rst = rewardStatus.toLowerCase();
    final ost = ocrStatus.toLowerCase();
    return st == 'proof_rejected' ||
        rst == 'rejected_by_app' ||
        rst == 'rejected';
  }
  bool get isRewardWaiting =>
      !isCompleted &&
      !isDisputed &&
      !isProofRejected &&
      (status.toLowerCase() == 'reward_waiting' ||
          rewardStatus.toLowerCase() == 'pending' ||
          rewardStatus.toLowerCase() == 'pending_host' ||
          ((proofUrl != null && proofUrl!.isNotEmpty) ||
              (winProofUrl != null && winProofUrl!.isNotEmpty)));
  bool get isInProgress =>
      !isCompleted &&
      !isRewardWaiting &&
      !isDisputed &&
      !isProofRejected &&
      (status.toUpperCase() == 'IN_PROGRESS' ||
          status.toUpperCase() == 'STARTED' ||
          status.toUpperCase() == 'MATCH_STARTED');
  bool get isActive =>
      !isCompleted &&
      !isRewardWaiting &&
      !isDisputed &&
      !isProofRejected &&
      (status.toLowerCase() == 'active' || status.toUpperCase() == 'OPEN');
  bool get isExpiredCompleted {
    if (!isCompleted || completedAt == null) return false;
    return DateTime.now().difference(completedAt!).inMinutes >= 5;
  }

  factory GamerRoom.fromSupabase(Map<String, dynamic> row) {
    DateTime created = DateTime.now();
    if (row['created_at'] is String) {
      created = DateTime.tryParse(row['created_at']) ?? created;
    }
    final joinedUserIds = (row['joined_user_ids'] is List)
        ? List<String>.from(
            (row['joined_user_ids'] as List).map((e) => e.toString()))
        : <String>[];
    final joinedUsers = <Map<String, dynamic>>[];
    if (row['joined_users'] is List) {
      for (final item in (row['joined_users'] as List)) {
        if (item is Map) {
          joinedUsers.add(Map<String, dynamic>.from(item));
        }
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
      prizePool:
          (row['prize_pool'] is num) ? (row['prize_pool'] as num).toInt() : 0,
      totalSlots: (row['total_slots'] is num)
          ? (row['total_slots'] as num).toInt()
          : 2,
      filledSlots: (row['filled_slots'] is num)
          ? (row['filled_slots'] as num).toInt()
          : 1,
      status: (row['status'] ?? 'active').toString(),
      createdAt: created,
      hostName: (row['host_name'] ?? 'Host').toString(),
      joinedUserIds: joinedUserIds,
      joinedUsers: joinedUsers,
      startTime: startTime ?? created,
      rewardStatus: (row['reward_status'] ?? 'idle').toString(),
      winnerId: row['winner_id']?.toString(),
      winnerName: row['winner_name']?.toString(),
      ocrStatus: (row['ocr_status'] ?? 'none').toString(),
      ocrText: (row['ocr_text'] ?? '').toString(),
      ocrScore:
          (row['ocr_score'] is num) ? (row['ocr_score'] as num).toInt() : 0,
      proofUrl: row['proof_url']?.toString(),
      winProofUrl: row['win_proof_url']?.toString(),
      winProofUploadedAt: winProofUploadedAt,
      completedAt: completedAt,
      autoApproveAt: autoApproveAt,
      disputed: row['disputed'] == true,
      disputedBy: row['disputed_by']?.toString(),
      disputedByName: row['disputed_by_name']?.toString(),
      disputeReason: row['dispute_reason']?.toString(),
      disputeProofUrl: row['dispute_proof_url']?.toString(),
      disputedAt: disputedAt,
    );
  }
}

class GamerRoomsScreen extends StatefulWidget {
  const GamerRoomsScreen({super.key});

  @override
  State<GamerRoomsScreen> createState() => _GamerRoomsScreenState();
}

class _GamerRoomsScreenState extends State<GamerRoomsScreen> {
  final TournamentService _tournamentService = TournamentService();
  final GamerAuthService _authService = GamerAuthService();
  final CoinWalletService _walletService = CoinWalletService();

  final Set<String> _joinedRoomIds = <String>{};
  String _selectedCategory = 'All Games';
  bool _isWatchingAdFromRooms = false;

  static const Color _fbBlue = Color(0xFF1877F2);

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
      SupabaseService.client.auth.currentUser?.userMetadata?["full_name"]
          ?.toString() ??
      'Gamer';

  String get currentUserPhoto =>
      _authService.currentGamer?.photoUrl ??
      SupabaseService.client.auth.currentUser?.userMetadata?["avatar_url"]
          ?.toString() ??
      '';

  Timer? _cleanupTimer;

  String _getCompletedDeleteRemainingText(GamerRoom room) {
    if (room.completedAt == null) return 'COMPLETED';
    final elapsedSec = DateTime.now().difference(room.completedAt!).inSeconds;
    final remainingSec = (300 - elapsedSec).clamp(0, 300);
    if (remainingSec <= 0) return 'AUTO-DELETING...';
    final mins = remainingSec ~/ 60;
    final secs = remainingSec % 60;
    return 'COMPLETED (${mins}m ${secs.toString().padLeft(2, '0')}s)';
  }

  @override
  void initState() {
    super.initState();
    _walletService.getOrCreateWallet(currentUserId);
    _walletService.addListener(_onWalletChanged);
    _cleanupTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      setState(() {});
      _purgeExpiredCompletedRooms();
      _checkAutoApproveRooms();
    });
  }

  void _onWalletChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _walletService.removeListener(_onWalletChanged);
    super.dispose();
  }

  Future<void> _purgeExpiredCompletedRooms() async {
    try {
      final now = DateTime.now();
      final rows = await SupabaseService.client
          .from('rooms')
          .select()
          .eq('status', 'completed');
      for (final row in (rows as List)) {
        final data = Map<String, dynamic>.from(row);
        DateTime? completedAt;
        if (data['completed_at'] is String) {
          completedAt = DateTime.tryParse(data['completed_at']);
        }
        if (completedAt != null &&
            now.difference(completedAt).inMinutes >= 5) {
          final id = data['id'];
          await SupabaseService.client.from('rooms').delete().eq('id', id);
        }
      }
    } catch (_) {}
  }

  Future<void> _checkAutoApproveRooms() async {
    try {
      final now = DateTime.now();
      final rows = await SupabaseService.client
          .from('rooms')
          .select()
          .eq('status', 'reward_waiting');
      for (final row in (rows as List)) {
        final data = Map<String, dynamic>.from(row);
        if (data['disputed'] == true || data['status'] == 'disputed') continue;
        DateTime? autoApproveAt;
        if (data['auto_approve_at'] is String) {
          autoApproveAt = DateTime.tryParse(data['auto_approve_at']);
        }
        if (autoApproveAt == null && data['win_proof_uploaded_at'] != null) {
          if (data['win_proof_uploaded_at'] is String) {
            final p = DateTime.tryParse(data['win_proof_uploaded_at']);
            if (p != null) autoApproveAt = p.add(const Duration(minutes: 15));
          }
        }
        if (autoApproveAt != null && now.isAfter(autoApproveAt)) {
          final room = GamerRoom.fromSupabase(data);
          await _executeAutoApprove(room);
        }
      }
    } catch (_) {}
  }

  Future<void> _executeAutoApprove(GamerRoom room) async {
    try {
      final row = await SupabaseService.client
          .from('rooms')
          .select()
          .eq('id', room.id)
          .maybeSingle();
      if (row == null) return;
      final data = Map<String, dynamic>.from(row);
      if (data['reward_status'] == 'sent' ||
          data['status'] == 'completed' ||
          data['disputed'] == true) {
        return;
      }
      String resolvedWinnerId =
          (data['winner_id'] ?? room.winnerId ?? '').toString();
      String resolvedWinnerName =
          (data['winner_name'] ?? room.winnerName ?? '').toString();
      if (resolvedWinnerId.isEmpty || resolvedWinnerId == 'guest') {
        if (room.joinedUsers.length > 1) {
          resolvedWinnerId = (room.joinedUsers[1]['id'] ?? '').toString();
          resolvedWinnerName =
              (room.joinedUsers[1]['name'] ?? 'Winner').toString();
        } else if (room.joinedUserIds.length > 1) {
          resolvedWinnerId = room.joinedUserIds[1];
          resolvedWinnerName = 'Winner';
        }
      }
      if (resolvedWinnerName.isEmpty) resolvedWinnerName = 'Winner';
      final int prize = room.prize;
      final winnerRow = await SupabaseService.client
          .from('users')
          .select()
          .eq('id', resolvedWinnerId)
          .maybeSingle();
      int currentCoins = 0;
      int currentWins = 0;
      int currentWinnings = 0;
      if (winnerRow != null) {
        final wd = Map<String, dynamic>.from(winnerRow);
        currentCoins = (wd['gCoins'] ?? wd['coins'] ?? 0) is num
            ? ((wd['gCoins'] ?? wd['coins']) as num).toInt()
            : 0;
        currentWins = (wd['wins'] ?? 0) is num
            ? (wd['wins'] as num).toInt()
            : 0;
        currentWinnings = (wd['totalWinnings'] ?? 0) is num
            ? (wd['totalWinnings'] as num).toInt()
            : 0;
      }
      final updatedCoins = currentCoins + prize;
      if (winnerRow != null) {
        await SupabaseService.client.from('users').update({
          'gCoins': updatedCoins,
          'coins': updatedCoins,
          'totalWinnings': currentWinnings + prize,
          'wins': currentWins + 1,
          'lastRewardAt': DateTime.now().toIso8601String(),
        }).eq('id', resolvedWinnerId);
      } else {
        await SupabaseService.client.from('users').upsert({
          'id': resolvedWinnerId,
          'gCoins': updatedCoins,
          'coins': updatedCoins,
          'totalWinnings': prize,
          'wins': 1,
          'lastRewardAt': DateTime.now().toIso8601String(),
        });
      }
      await SupabaseService.client.from('rooms').update({
        'reward_status': 'sent',
        'status': 'completed',
        'winner_id': resolvedWinnerId,
        'winner_name': resolvedWinnerName,
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', room.id);
      try {
        await SupabaseService.client.from('messages').insert({
          'room_id': room.id,
          'sender_id': 'system',
          'sender_name': 'ROOM BOT',
          'message':
              '🏆 REWARD AUTO-SENT! $prize Coins sent to $resolvedWinnerName!',
          'type': 'system_reward',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    } catch (e) {
      debugPrint('Auto-approve error: $e');
    }
  }

  Stream<List<GamerRoom>> _getRoomsStream() {
    return SupabaseService.client
        .from('rooms')
        .stream(primaryKey: ['id'])
        .map((rows) {
      final list = <GamerRoom>[];
      for (final row in rows) {
        try {
          final room = GamerRoom.fromSupabase(Map<String, dynamic>.from(row));
          if (room.isExpiredCompleted) {
            SupabaseService.client
                .from('rooms')
                .delete()
                .eq('id', room.id)
                .catchError((_) {});
            continue;
          }
          list.add(room);
        } catch (_) {}
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> joinRoom(GamerRoom room) async {
    final uid = currentUserId;
    final name = currentUserName;
    final isAlreadyJoined =
        _joinedRoomIds.contains(room.id) || room.joinedUserIds.contains(uid);
    final isHost = room.hostId == uid;
    if (isAlreadyJoined || isHost) {
      _showRoomBottomSheet(room);
      return;
    }
    if (room.filled >= room.total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room Full!'),
          backgroundColor: GamerTheme.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await AdFreeService().showRewardedAdForAction(
      context: context,
      actionTitle: 'Watch 1 Ad to Join Room',
      onRewardEarned: () async {
        try {
          final row = await SupabaseService.client
              .from('rooms')
              .select()
              .eq('id', room.id)
              .maybeSingle();
          if (row == null) throw Exception('Room does not exist');
          final data = Map<String, dynamic>.from(row);
          final int total = (data['total_slots'] ?? 2) is num
              ? (data['total_slots'] as num).toInt()
              : 2;
          final int currentFilled = (data['filled_slots'] ?? 0) is num
              ? (data['filled_slots'] as num).toInt()
              : 0;
          if (currentFilled >= total) throw Exception('full');
          final List joinedIds = (data['joined_user_ids'] is List)
              ? List.from(data['joined_user_ids'])
              : [];
          if (joinedIds.contains(uid)) return;
          final newJoinedIds = [...joinedIds, uid];
          final List joinedUsersList = (data['joined_users'] is List)
              ? List.from(data['joined_users'])
              : [];
          joinedUsersList.add({
            'id': uid,
            'name': name,
            'photo': currentUserPhoto,
            'joinedAt': DateTime.now().toIso8601String(),
          });
          await SupabaseService.client.from('rooms').update({
            'filled_slots': currentFilled + 1,
            'joined_user_ids': jsonEncode(newJoinedIds),
            'joined_users': jsonEncode(joinedUsersList),
          }).eq('id', room.id);
          if (mounted) {
            setState(() => _joinedRoomIds.add(room.id));
            await _walletService.recordTournamentJoinedAndCheckReferral(uid);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Joined! Free Entry'),
                backgroundColor: _fbBlue,
                behavior: SnackBarBehavior.floating,
              ),
            );
            _showRoomBottomSheet(room);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.toString().contains('full')
                    ? 'Room is full'
                    : 'Could not join room: $e'),
                backgroundColor: GamerTheme.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
    );
  }

  void _showRoomBottomSheet(GamerRoom room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: _InRoomBottomSheetContent(
          room: room,
          currentUserId: currentUserId,
          currentUserName: currentUserName,
          onJoinRoomRequested: () {
            Navigator.pop(ctx);
            joinRoom(room);
          },
          onLeaveRoom: () async {
            final uid = currentUserId;
            try {
              final row = await SupabaseService.client
                  .from('rooms')
                  .select()
                  .eq('id', room.id)
                  .maybeSingle();
              if (row == null) return;
              final data = Map<String, dynamic>.from(row);
              final List joinedIds = (data['joined_user_ids'] is List)
                  ? List.from(data['joined_user_ids'])
                  : [];
              joinedIds.remove(uid);
              final List joinedUsersList = (data['joined_users'] is List)
                  ? List.from(data['joined_users'])
                  : [];
              joinedUsersList.removeWhere(
                  (u) => u is Map && u['id'] == uid);
              final int currentFilled =
                  (data['filled_slots'] ?? 1) is num
                      ? (data['filled_slots'] as num).toInt()
                      : 1;
              await SupabaseService.client.from('rooms').update({
                'filled_slots': (currentFilled - 1).clamp(0, 100),
                'joined_user_ids': jsonEncode(joinedIds),
                'joined_users': jsonEncode(joinedUsersList),
              }).eq('id', room.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                setState(() => _joinedRoomIds.remove(room.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('You left the room.'),
                    backgroundColor: GamerTheme.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e) {
              debugPrint('Error leaving room: $e');
            }
          },
        ),
      ),
    );
  }

  void _showCreateRoomDialog() {
    String selectedGame =
        _selectedCategory == 'All Games' ? 'BGMI' : _selectedCategory;
    String selectedMap = 'Erangel';
    int maxSlots = 2;
    int prizeCoins = 100;

    String generateRoomTitle(String map, int slots, int prize) {
      final String slotPart =
          (slots == 2) ? '1v1' : (slots == 4 ? '2v2' : '$slots slots');
      return '$selectedGame $map $slotPart - $prize Coins';
    }

    final titleController = TextEditingController(
      text: generateRoomTitle(selectedMap, maxSlots, prizeCoins),
    );
    final roomIdController = TextEditingController();
    final passController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final bool isRoomIdEmpty = roomIdController.text.trim().isEmpty;
          final bool isPassEmpty = passController.text.trim().isEmpty;
          final bool isPublishEnabled = !isRoomIdEmpty && !isPassEmpty;
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.add_moderator_rounded,
                          color: Color(0xFF1877F2), size: 22),
                      const SizedBox(width: 8),
                      const Text('Host Custom Room',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 17)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Color(0xFF65676B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('SELECT GAME',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedGame,
                    items: _gameCategories
                        .where((g) => g != 'All Games')
                        .map((g) =>
                            DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() {
                          selectedGame = val;
                          titleController.text = generateRoomTitle(
                              selectedMap, maxSlots, prizeCoins);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('ROOM TITLE',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(controller: titleController),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('MAP',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: selectedMap,
                              items: const [
                                DropdownMenuItem(
                                    value: 'Erangel', child: Text('Erangel')),
                                DropdownMenuItem(
                                    value: 'Miramar', child: Text('Miramar')),
                                DropdownMenuItem(
                                    value: 'Sanhok', child: Text('Sanhok')),
                                DropdownMenuItem(
                                    value: 'Vikendi', child: Text('Vikendi')),
                                DropdownMenuItem(
                                    value: 'Livik', child: Text('Livik')),
                                DropdownMenuItem(
                                    value: 'Karakin', child: Text('Karakin')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setSheetState(() {
                                    selectedMap = val;
                                    titleController.text = generateRoomTitle(
                                        selectedMap, maxSlots, prizeCoins);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SLOTS',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              value: maxSlots,
                              items: const [
                                DropdownMenuItem(
                                    value: 2, child: Text('2 (1v1)')),
                                DropdownMenuItem(
                                    value: 4, child: Text('4 (2v2)')),
                                DropdownMenuItem(
                                    value: 10, child: Text('10 slots')),
                                DropdownMenuItem(
                                    value: 12, child: Text('12 slots')),
                                DropdownMenuItem(
                                    value: 24, child: Text('24 slots')),
                                DropdownMenuItem(
                                    value: 50, child: Text('50 slots')),
                                DropdownMenuItem(
                                    value: 100, child: Text('100 slots')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setSheetState(() {
                                    maxSlots = val;
                                    titleController.text = generateRoomTitle(
                                        selectedMap, maxSlots, prizeCoins);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('PRIZE POOL',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: prizeCoins,
                    items: const [
                      DropdownMenuItem(
                          value: 100, child: Text('💰 100 Coins')),
                      DropdownMenuItem(
                          value: 250, child: Text('💰 250 Coins')),
                      DropdownMenuItem(
                          value: 500, child: Text('💰 500 Coins')),
                      DropdownMenuItem(
                          value: 1000, child: Text('💰 1000 Coins')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() {
                          prizeCoins = val;
                          titleController.text = generateRoomTitle(
                              selectedMap, maxSlots, prizeCoins);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: roomIdController,
                          onChanged: (_) => setSheetState(() {}),
                          decoration: InputDecoration(
                            labelText: 'IN-GAME ROOM ID *',
                            errorText:
                                isRoomIdEmpty ? 'Required' : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: passController,
                          onChanged: (_) => setSheetState(() {}),
                          decoration: InputDecoration(
                            labelText: 'PASSWORD *',
                            errorText: isPassEmpty ? 'Required' : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPublishEnabled
                            ? const Color(0xFF1877F2)
                            : const Color(0xFFE4E6EB),
                      ),
                      onPressed: isPublishEnabled
                          ? () async {
                              final uid = currentUserId;
                              final name = currentUserName;
                              if (uid.isEmpty) return;
                              final roomId =
                                  '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
                              final now = DateTime.now().toIso8601String();
                              try {
                                await SupabaseService.client.from('rooms').insert({
                                  'id': roomId,
                                  'host_id': uid,
                                  'game': selectedGame,
                                  'mode': selectedMap,
                                  'room_id': roomIdController.text.trim(),
                                  'room_password': passController.text.trim(),
                                  'prize_pool': prizeCoins,
                                  'total_slots': maxSlots,
                                  'filled_slots': 1,
                                  'status': 'active',
                                  'created_at': now,
                                  'host_name': name,
                                  'joined_user_ids': jsonEncode([uid]),
                                  'joined_users': jsonEncode([
                                    {
                                      'id': uid,
                                      'name': name,
                                      'photo': currentUserPhoto,
                                      'joinedAt': now,
                                    }
                                  ]),
                                  'start_time': now,
                                });
                                if (mounted) {
                                  setState(() => _joinedRoomIds.add(roomId));
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('🎉 Room published!'),
                                      backgroundColor: _fbBlue,
                                    ),
                                  );
                                }
                              } catch (e) {
                                debugPrint('Room insert failed: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed: $e'),
                                      backgroundColor: GamerTheme.redAccent,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 6),
                                    ),
                                  );
                                }
                              }
                            }
                          : null,
                      child: const Text('PUBLISH ROOM',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
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

  Widget _buildRoomCard(GamerRoom room) {
    final uid = currentUserId;
    final bool isHost = room.hostId == uid;
    final bool isJoined = _joinedRoomIds.contains(room.id) ||
        room.joinedUserIds.contains(uid);
    final int total = room.total > 0 ? room.total : 2;
    final int filled = room.filled.clamp(0, total);
    final double fillRatio =
        total > 0 ? (filled / total).clamp(0.0, 1.0) : 0.0;
    final initial = isHost || isJoined
        ? (currentUserName.isNotEmpty
            ? currentUserName[0].toUpperCase()
            : 'Y')
        : (room.hostName.isNotEmpty
            ? room.hostName[0].toUpperCase()
            : 'G');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isJoined ? const Color(0xFF1877F2) : const Color(0xFFE4E6EB),
          width: isJoined ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isJoined
                    ? const Color(0xFF1877F2)
                    : const Color(0xFFE4E6EB),
                child: Text(initial,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.title,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('Host: ${room.hostName} • ${room.map}',
                        style: const TextStyle(
                            color: Color(0xFF65676B), fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(room.game,
                    style: const TextStyle(
                        color: Color(0xFF1877F2),
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(children: [
                    Text('${room.prize} Coins',
                        style: const TextStyle(
                            color: Color(0xFF1877F2),
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    const Text('PRIZE POOL',
                        style:
                            TextStyle(fontSize: 10, color: Color(0xFF65676B))),
                  ]),
                ),
                Expanded(
                  child: Column(children: const [
                    Text('FREE',
                        style: TextStyle(
                            color: Color(0xFF1877F2),
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    Text('ENTRY FEE',
                        style:
                            TextStyle(fontSize: 10, color: Color(0xFF65676B))),
                  ]),
                ),
                Expanded(
                  child: Column(children: [
                    Text('$filled/$total',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const Text('SLOTS',
                        style:
                            TextStyle(fontSize: 10, color: Color(0xFF65676B))),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fillRatio,
              minHeight: 4,
              backgroundColor: const Color(0xFFE4E6EB),
              valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF1877F2)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                room.isCompleted
                    ? 'COMPLETED'
                    : room.isDisputed
                        ? 'DISPUTED'
                        : room.isInProgress
                            ? 'MATCH LIVE'
                            : 'ACTIVE',
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (room.isFull && !isJoined && !isHost)
                ElevatedButton(
                  onPressed: null,
                  child: const Text('FULL'),
                )
              else if (isHost)
                OutlinedButton(
                  onPressed: () => _showRoomBottomSheet(room),
                  child: const Text('MANAGE ✓'),
                )
              else if (isJoined)
                ElevatedButton(
                  onPressed: () => _showRoomBottomSheet(room),
                  child: const Text('JOINED ✓'),
                )
              else
                ElevatedButton(
                  onPressed: () => joinRoom(room),
                  child: const Text('JOIN ROOM'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 44,
              color: Colors.white,
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Text('Rooms',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _showCreateRoomDialog,
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _gameCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final name = _gameCategories[idx];
                    final isSelected = _selectedCategory == name;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = name),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1877F2)
                              : const Color(0xFFE4E6EB),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Text(name,
                            style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF050505),
                                fontSize: 12.5,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600)),
                      ),
                    );
                  },
                ),
              ),
            ),
            const Divider(color: Color(0xFFE4E6EB), height: 1),
            Expanded(
              child: StreamBuilder<List<GamerRoom>>(
                stream: _getRoomsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF1877F2)));
                  }
                  final allRooms = snapshot.data ?? [];
                  final filtered = allRooms.where((r) {
                    if (_selectedCategory == 'All Games') return true;
                    return r.game.toLowerCase().trim() ==
                        _selectedCategory.toLowerCase().trim();
                  }).toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.sports_esports_rounded,
                              size: 44, color: Color(0xFF65676B)),
                          const SizedBox(height: 14),
                          const Text('No rooms found',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Host First Room'),
                            onPressed: _showCreateRoomDialog,
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 120, top: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _buildRoomCard(filtered[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1877F2),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_moderator_rounded),
        label: const Text('HOST ROOM',
            style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showCreateRoomDialog,
      ),
    );
  }
}

class _InRoomBottomSheetContent extends StatefulWidget {
  final GamerRoom room;
  final String currentUserId;
  final String currentUserName;
  final VoidCallback onJoinRoomRequested;
  final VoidCallback onLeaveRoom;

  const _InRoomBottomSheetContent({
    required this.room,
    required this.currentUserId,
    required this.currentUserName,
    required this.onJoinRoomRequested,
    required this.onLeaveRoom,
  });

  @override
  State<_InRoomBottomSheetContent> createState() =>
      _InRoomBottomSheetContentState();
}

class _InRoomBottomSheetContentState extends State<_InRoomBottomSheetContent> {
  final TextEditingController _msgController = TextEditingController();
  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;
  bool _isStartingMatch = false;

  bool get isHost => widget.room.hostId == widget.currentUserId;
  bool get isJoined =>
      widget.room.joinedUserIds.contains(widget.currentUserId);
  bool get canAccess => isHost || isJoined;

  @override
  void initState() {
    super.initState();
    _updateRemainingTime();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _updateRemainingTime());
    });
  }

  void _updateRemainingTime() {
    final now = DateTime.now();
    _remainingTime = widget.room.startTime.isAfter(now)
        ? widget.room.startTime.difference(now)
        : Duration.zero;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _msgController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative || d == Duration.zero) return 'MATCH STARTED';
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    if (hours > 0) return 'Starts in: ${hours}h ${minutes}m ${seconds}s';
    return 'Starts in: ${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final isH = room.hostId == widget.currentUserId;
    final isJ = room.joinedUserIds.contains(widget.currentUserId);
    final access = isH || isJ;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF0F2F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFCED0D4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(room.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Host: ${room.hostName} • ${room.map}',
                            style: const TextStyle(
                                color: Color(0xFF65676B), fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Prize: ${room.prize} Coins • Slots: ${room.filled}/${room.total}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F3FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        room.isCompleted
                            ? 'COMPLETED'
                            : room.isInProgress
                                ? 'MATCH IN PROGRESS'
                                : _formatDuration(_remainingTime),
                        style: const TextStyle(
                            color: Color(0xFF1877F2),
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCED0D4)),
                      ),
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: SupabaseService.client
                            .from('messages')
                            .stream(primaryKey: ['id'])
                            .eq('room_id', room.id)
                            .map((rows) => rows
                                .map((r) => Map<String, dynamic>.from(r))
                                .toList()),
                        builder: (context, snapshot) {
                          final docs = snapshot.data ?? [];
                          if (docs.isEmpty) {
                            return const Center(
                              child: Text('No messages yet',
                                  style: TextStyle(
                                      color: Color(0xFF65676B),
                                      fontSize: 12)),
                            );
                          }
                          return ListView.builder(
                            itemCount: docs.length,
                            padding: const EdgeInsets.all(10),
                            itemBuilder: (context, index) {
                              final msg = docs[index];
                              final senderId =
                                  msg['sender_id']?.toString() ?? '';
                              final text =
                                  msg['message']?.toString() ?? '';
                              final isSystem = senderId == 'system' ||
                                  msg['type'] == 'system';
                              final isMe =
                                  senderId == widget.currentUserId;
                              if (isSystem) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4),
                                  child: Center(
                                    child: Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE4E6EB),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(text,
                                          style: const TextStyle(
                                              color: Color(0xFF1877F2),
                                              fontSize: 11,
                                              fontWeight:
                                                  FontWeight.bold)),
                                    ),
                                  ),
                                );
                              }
                              return Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin:
                                      const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? const Color(0xFF1877F2)
                                        : const Color(0xFFE4E6EB),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Text(text,
                                      style: TextStyle(
                                          color: isMe
                                              ? Colors.white
                                              : const Color(0xFF050505),
                                          fontSize: 12)),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (access)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _msgController,
                              decoration: const InputDecoration(
                                hintText: 'Type a message...',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                    borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () async {
                              final text = _msgController.text.trim();
                              if (text.isEmpty) return;
                              _msgController.clear();
                              await SupabaseService.client
                                  .from('messages')
                                  .insert({
                                'room_id': room.id,
                                'sender_id': widget.currentUserId,
                                'sender_name': widget.currentUserName,
                                'message': text,
                                'type': 'text',
                                'created_at':
                                    DateTime.now().toIso8601String(),
                              });
                            },
                            icon: const Icon(Icons.send_rounded,
                                color: Color(0xFF1877F2)),
                          ),
                        ],
                      )
                    else
                      ElevatedButton(
                        onPressed: widget.onJoinRoomRequested,
                        child: const Text('JOIN ROOM - FREE'),
                      ),
                    const SizedBox(height: 12),
                    if (isH)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(_isStartingMatch
                            ? 'STARTING...'
                            : 'START MATCH'),
                        onPressed: _isStartingMatch
                            ? null
                            : () async {
                                setState(() => _isStartingMatch = true);
                                try {
                                  await SupabaseService.client
                                      .from('rooms')
                                      .update({
                                    'status': 'IN_PROGRESS',
                                  }).eq('id', room.id);
                                } catch (_) {}
                                if (mounted) {
                                  setState(
                                      () => _isStartingMatch = false);
                                }
                              },
                      ),
                    if (isJ && !isH)
                      OutlinedButton(
                        onPressed: widget.onLeaveRoom,
                        child: const Text('LEAVE ROOM'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}