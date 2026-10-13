import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
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
import '../services/notification_service.dart';
import 'coin_store_screen.dart';
import '../widgets/coin_history_sheet.dart';
import '../widgets/coin_or_ad_popup.dart';

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
  final int entryFeeCoins;
  final DateTime? boostedUntil;
  final int proofRejectCount;

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
    this.entryFeeCoins = 0,
    this.boostedUntil,
    this.proofRejectCount = 0,
  }) : startTime = startTime ?? createdAt;

  String get title => '$game $mode';
  String get map => mode;
  int get prize => prizePool;
  int get total => totalSlots;
  int get filled => filledSlots;
  String get roomIdCode => roomId;
  String get password => roomPassword;
  String get entryFee => entryFeeCoins == 0 ? 'FREE' : '$entryFeeCoins Coins';
  String get prizeSource => 'application';

  bool get isBoosted {
    if (boostedUntil == null) return false;
    return DateTime.now().isBefore(boostedUntil!);
  }

  bool get isFeatured {
    if (!isBoosted) return false;
    return boostedUntil!.difference(DateTime.now()).inHours > 48;
  }

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
    return st == 'proof_rejected' ||
        rst == 'rejected_by_app' ||
        rst == 'rejected';
  }
  bool get isProofSubmitted =>
      !isCompleted &&
      !isDisputed &&
      (status.toLowerCase() == 'proof_submitted' ||
          rewardStatus.toLowerCase() == 'pending_approval' ||
          status.toLowerCase() == 'auto_approved' ||
          ((winProofUrl != null && winProofUrl!.isNotEmpty) &&
              status.toLowerCase() != 'reward_waiting' &&
              !isProofRejected));
  bool get isRewardWaiting =>
      !isCompleted &&
      !isDisputed &&
      !isProofRejected &&
      !isProofSubmitted &&
      (status.toLowerCase() == 'reward_waiting' ||
          rewardStatus.toLowerCase() == 'pending' ||
          rewardStatus.toLowerCase() == 'pending_host');
  bool get isInProgress =>
      !isCompleted &&
      !isRewardWaiting &&
      !isProofSubmitted &&
      !isDisputed &&
      !isProofRejected &&
      (status.toUpperCase() == 'IN_PROGRESS' ||
          status.toUpperCase() == 'STARTED' ||
          status.toUpperCase() == 'MATCH_STARTED');
  bool get isActive =>
      !isCompleted &&
      !isRewardWaiting &&
      !isProofSubmitted &&
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

    List<String> joinedUserIds = <String>[];
    final rawIds = row['joined_user_ids'];
    if (rawIds is List) {
      joinedUserIds = List<String>.from(rawIds.map((e) => e.toString()));
    } else if (rawIds is String && rawIds.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawIds);
        if (decoded is List) {
          joinedUserIds =
              List<String>.from(decoded.map((e) => e.toString()));
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
    DateTime? boostedUntil;
    if (row['boosted_until'] is String) {
      boostedUntil = DateTime.tryParse(row['boosted_until']);
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
      entryFeeCoins: (row['entry_fee_coins'] is num)
          ? (row['entry_fee_coins'] as num).toInt()
          : 0,
      boostedUntil: boostedUntil,
      proofRejectCount: (row['proof_reject_count'] is num)
          ? (row['proof_reject_count'] as num).toInt()
          : ((row['proof_upload_count'] is num)
              ? (row['proof_upload_count'] as num).toInt()
              : 0),
    );
  }
}

class GamerRoomsScreen extends StatefulWidget {
  const GamerRoomsScreen({super.key});

  /// FEATURE 5: Complete Prize Distribution & Room Close
  static Future<void> distributePrizeAndComplete({
    required GamerRoom room,
    required String winnerId,
    required String winnerName,
  }) async {
    final prize = room.prize;

    // 1. Call CoinWalletService.updateCoins() with type='win_prize'
    try {
      await CoinWalletService.updateCoins(
        userId: winnerId,
        amount: prize,
        type: 'win_prize',
        roomId: room.id,
        description: 'Tournament room win prize: ${room.title}',
      );
    } catch (e) {
      debugPrint('updateCoins win_prize error: $e');
    }

    // 2. Winner's wins counter +1, total_winnings increased
    try {
      final winnerRow = await SupabaseService.client
          .from('users')
          .select('wins, totalWinnings, total_winnings')
          .or('id.eq.$winnerId,uid.eq.$winnerId')
          .maybeSingle();
      if (winnerRow != null) {
        final wd = Map<String, dynamic>.from(winnerRow);
        final currentWins = (wd['wins'] as num?)?.toInt() ?? 0;
        final currentWinnings = (wd['total_winnings'] as num?)?.toInt() ??
            (wd['totalWinnings'] as num?)?.toInt() ??
            0;
        await SupabaseService.client.from('users').update({
          'wins': currentWins + 1,
          'total_winnings': currentWinnings + prize,
          'totalWinnings': currentWinnings + prize,
        }).or('id.eq.$winnerId,uid.eq.$winnerId');
      }
    } catch (_) {}

    // 3. Update room status to 'completed' and completed_at = now()
    await SupabaseService.client.from('rooms').update({
      'reward_status': 'sent',
      'status': 'completed',
      'winner_id': winnerId,
      'winner_name': winnerName,
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', room.id);

    // 4. System chat message: "🏆 [winner name] won! +[prize] coins"
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

    // 5. In-app notification sent to winner: "🏆 You won! +[prize] coins"
    try {
      await NotificationService().sendNotification(
        userId: winnerId,
        type: 'match_result',
        title: '🏆 You won! +$prize coins',
        body: 'Congratulations $winnerName! You won the match in ${room.title} and received $prize coins.',
        data: {'room_id': room.id, 'prize': prize},
        priority: 'high',
      );
    } catch (e) {
      debugPrint('Notification to winner error: $e');
    }

    // 6. In-app notification sent to loser: "Match finished. Better luck next time"
    for (final uid in room.joinedUserIds) {
      if (uid.isNotEmpty && uid != winnerId && uid != 'guest') {
        try {
          await NotificationService().sendNotification(
            userId: uid,
            type: 'match_result',
            title: 'Match Finished',
            body: 'Match finished. Better luck next time',
            data: {'room_id': room.id},
          );
        } catch (_) {}
      }
    }
  }

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

  String _generateUuid() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(0xFFFFFF);
    String hex(int n, int len) =>
        n.toRadixString(16).padLeft(len, '0').substring(0, len);
    final p1 = hex(now & 0xFFFFFFFF, 8);
    final p2 = hex((now >> 32) & 0xFFFF, 4);
    final p3 = '4${hex((now >> 16) & 0xFFF, 3)}';
    final p4 = '${'89ab'[(rand >> 8) & 3]}${hex(rand & 0xFFF, 3)}';
    final p5 = hex((now * 31 + rand) & 0xFFFFFFFFFFFF, 12);
    return '$p1-$p2-$p3-$p4-$p5';
  }

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
      _checkAutoEndInProgressRooms();
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
            now.difference(completedAt).inSeconds >= 300) {
          final id = data['id'];
          await SupabaseService.client.from('rooms').delete().eq('id', id);
        }
      }
    } catch (_) {}
  }

  /// FEATURE 1 (Option B): Auto-end match after 1 hour duration
  Future<void> _checkAutoEndInProgressRooms() async {
    try {
      final now = DateTime.now();
      final rows = await SupabaseService.client
          .from('rooms')
          .select()
          .eq('status', 'IN_PROGRESS');
      for (final row in (rows as List)) {
        final data = Map<String, dynamic>.from(row);
        DateTime? startTime;
        if (data['start_time'] is String) {
          startTime = DateTime.tryParse(data['start_time']);
        }
        if (startTime == null && data['created_at'] is String) {
          startTime = DateTime.tryParse(data['created_at']);
        }
        if (startTime != null && now.difference(startTime).inHours >= 1) {
          final roomId = data['id'];
          await SupabaseService.client.from('rooms').update({
            'status': 'reward_waiting',
            'reward_status': 'pending',
          }).eq('id', roomId);
          try {
            await SupabaseService.client.from('messages').insert({
              'room_id': roomId,
              'sender_id': 'system',
              'sender_name': 'ROOM BOT',
              'message':
                  '⏰ Match auto-ended after 1 hour! Winner, please upload winning screenshot to claim prize 🏆',
              'type': 'system',
              'created_at': DateTime.now().toIso8601String(),
            });
          } catch (_) {}
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

      await GamerRoomsScreen.distributePrizeAndComplete(
        room: room,
        winnerId: resolvedWinnerId,
        winnerName: resolvedWinnerName,
      );
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
          if (room.status.toLowerCase() == 'completed' &&
              room.completedAt != null &&
              DateTime.now().difference(room.completedAt!).inMinutes >= 5) {
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
      list.sort((a, b) {
        if (a.isBoosted && !b.isBoosted) return -1;
        if (!a.isBoosted && b.isBoosted) return 1;
        if (a.isBoosted && b.isBoosted) {
          if (a.isFeatured && !b.isFeatured) return -1;
          if (!a.isFeatured && b.isFeatured) return 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
      return list;
    });
  }

  Future<bool> _hasActiveRoom(String uid) async {
    if (uid.isEmpty || uid == 'guest') return false;
    try {
      final existing = await SupabaseService.client
          .from('rooms')
          .select('id')
          .eq('host_id', uid)
          .inFilter('status', ['active', 'IN_PROGRESS', 'reward_waiting'])
          .limit(1);
      return existing.isNotEmpty;
    } catch (e) {
      debugPrint('Active room check error: $e');
      return false;
    }
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

    final entryFee = room.entryFeeCoins;
    if (entryFee > 0) {
      final wallet = await _walletService.getOrCreateWallet(uid);
      if (wallet.coins < entryFee) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '⚠️ Not enough G-Coins! You need $entryFee coins to join. You have ${wallet.coins}.'),
              backgroundColor: GamerTheme.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }
    }

    await CoinOrAdPopup.show(
      context: context,
      actionName: 'Room Join',
      onConfirm: () async {
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

          if (entryFee > 0) {
            await CoinWalletService.updateCoins(
              userId: uid,
              amount: -entryFee,
              type: 'tournament_entry',
              title: 'Tournament Entry Fee 🎮',
              description: 'Entry fee for "${room.title}"',
              roomId: room.id,
            );
          }

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
              SnackBar(
                content: Text(entryFee > 0
                    ? 'Joined! $entryFee Coins deducted.'
                    : 'Joined! Free Entry'),
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
          onDeleteRoom: () async {
            final uid = currentUserId;
            if (room.hostId != uid) return;
            final confirm = await showDialog<bool>(
              context: context,
              builder: (dCtx) => AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Text('Delete Room?',
                    style: TextStyle(
                        color: Color(0xFF050505),
                        fontWeight: FontWeight.bold)),
                content: const Text(
                    'Are you sure? This will permanently delete your room.',
                    style: TextStyle(color: Color(0xFF65676B))),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dCtx, false),
                    child: const Text('Cancel',
                        style: TextStyle(color: Color(0xFF65676B))),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GamerTheme.redAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(dCtx, true),
                    child: const Text('DELETE',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
            if (confirm != true) return;
            try {
              await SupabaseService.client
                  .from('rooms')
                  .delete()
                  .eq('id', room.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                setState(() => _joinedRoomIds.remove(room.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🗑️ Room deleted.'),
                    backgroundColor: GamerTheme.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e) {
              debugPrint('Delete room error: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete: $e'),
                    backgroundColor: GamerTheme.redAccent,
                  ),
                );
              }
            }
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

  void _showCreateRoomDialog() async {
    final uid = currentUserId;
    if (uid.isEmpty || uid == 'guest') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to host a room'),
          backgroundColor: GamerTheme.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final hasActive = await _hasActiveRoom(uid);
    if (hasActive) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '⚠️ You already have an active room. Complete or delete it before creating a new one.'),
            backgroundColor: GamerTheme.accentOrange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    String selectedGame =
        _selectedCategory == 'All Games' ? 'BGMI' : _selectedCategory;
    String selectedMap = 'Erangel';
    int maxSlots = 2;
    int prizeCoins = 100;
    int entryFeeCoins = 0;

    String generateRoomTitle(
        String map, int slots, int prize, int fee) {
      final String slotPart =
          (slots == 2) ? '1v1' : (slots == 4 ? '2v2' : '$slots slots');
      final String feePart = fee == 0 ? 'FREE' : '$fee Coins';
      return '$selectedGame $map $slotPart - $prize Coins ($feePart Entry)';
    }

    final titleController = TextEditingController(
      text: generateRoomTitle(selectedMap, maxSlots, prizeCoins, entryFeeCoins),
    );
    final roomIdController = TextEditingController();
    final passController = TextEditingController();

    final bool isDark = GamerTheme.isDarkMode || Theme.of(context).brightness == Brightness.dark;
    final Color sheetBg = isDark ? GamerTheme.surfaceDark : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color labelColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final Color inputBg = isDark ? GamerTheme.cardElevated : const Color(0xFFF8FAFC);
    final Color inputBorder = isDark ? GamerTheme.borderDark : const Color(0xFFCBD5E1);
    final Color dropdownBg = isDark ? GamerTheme.cardElevated : Colors.white;

    InputDecoration buildFieldDecoration({String? label, String? hint, String? error}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        labelStyle: TextStyle(color: labelColor, fontSize: 12, fontWeight: FontWeight.bold),
        hintStyle: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8), fontSize: 12),
        filled: true,
        fillColor: inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1877F2), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: GamerTheme.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: GamerTheme.redAccent, width: 1.5),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final bool isRoomIdEmpty = roomIdController.text.trim().isEmpty;
          final bool isPassEmpty = passController.text.trim().isEmpty;
          final bool isPublishEnabled = !isRoomIdEmpty && !isPassEmpty;
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.9,
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 18,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      children: [
                        const Icon(Icons.add_moderator_rounded,
                            color: Color(0xFF1877F2), size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Host Custom Room',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: labelColor),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 1. SELECT GAME
                    Text(
                      'SELECT GAME',
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedGame,
                      dropdownColor: dropdownBg,
                      style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
                      decoration: buildFieldDecoration(),
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: labelColor),
                      items: _gameCategories
                          .where((g) => g != 'All Games')
                          .map((g) => DropdownMenuItem(
                                value: g,
                                child: Text(
                                  g,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() {
                            selectedGame = val;
                            titleController.text = generateRoomTitle(
                                selectedMap, maxSlots, prizeCoins, entryFeeCoins);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // 2. ROOM TITLE
                    Text(
                      'ROOM TITLE',
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500),
                      decoration: buildFieldDecoration(hint: 'Room Title'),
                    ),
                    const SizedBox(height: 12),

                    // 3. MAP & 4. SLOTS
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MAP',
                                style: TextStyle(
                                  color: labelColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: selectedMap,
                                dropdownColor: dropdownBg,
                                style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
                                decoration: buildFieldDecoration(),
                                icon: Icon(Icons.keyboard_arrow_down_rounded, color: labelColor),
                                items: const [
                                  'Erangel',
                                  'Miramar',
                                  'Sanhok',
                                  'Vikendi',
                                  'Livik',
                                  'Karakin',
                                ]
                                    .map((m) => DropdownMenuItem(
                                          value: m,
                                          child: Text(
                                            m,
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setSheetState(() {
                                      selectedMap = val;
                                      titleController.text = generateRoomTitle(
                                          selectedMap,
                                          maxSlots,
                                          prizeCoins,
                                          entryFeeCoins);
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
                              Text(
                                'SLOTS',
                                style: TextStyle(
                                  color: labelColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int>(
                                value: maxSlots,
                                dropdownColor: dropdownBg,
                                style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
                                decoration: buildFieldDecoration(),
                                icon: Icon(Icons.keyboard_arrow_down_rounded, color: labelColor),
                                items: const [
                                  MapEntry(2, '2 (1v1)'),
                                  MapEntry(4, '4 (2v2)'),
                                  MapEntry(10, '10 slots'),
                                  MapEntry(12, '12 slots'),
                                  MapEntry(24, '24 slots'),
                                  MapEntry(50, '50 slots'),
                                  MapEntry(100, '100 slots'),
                                ]
                                    .map((e) => DropdownMenuItem<int>(
                                          value: e.key,
                                          child: Text(
                                            e.value,
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setSheetState(() {
                                      maxSlots = val;
                                      titleController.text = generateRoomTitle(
                                          selectedMap,
                                          maxSlots,
                                          prizeCoins,
                                          entryFeeCoins);
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

                    // 5. PRIZE POOL
                    Text(
                      'PRIZE POOL',
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: prizeCoins,
                      dropdownColor: dropdownBg,
                      style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
                      decoration: buildFieldDecoration(),
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: labelColor),
                      items: const [
                        MapEntry(100, '💰 100 Coins'),
                        MapEntry(250, '💰 250 Coins'),
                        MapEntry(500, '💰 500 Coins'),
                        MapEntry(1000, '💰 1000 Coins'),
                      ]
                          .map((e) => DropdownMenuItem<int>(
                                value: e.key,
                                child: Text(
                                  e.value,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() {
                            prizeCoins = val;
                            titleController.text = generateRoomTitle(
                                selectedMap, maxSlots, prizeCoins, entryFeeCoins);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // 6. ENTRY FEE
                    Text(
                      'ENTRY FEE',
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: entryFeeCoins,
                      dropdownColor: dropdownBg,
                      style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
                      decoration: buildFieldDecoration(),
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: labelColor),
                      items: const [
                        MapEntry(0, '🆓 FREE Entry'),
                        MapEntry(50, '💰 50 Coins'),
                        MapEntry(200, '💰 200 Coins'),
                        MapEntry(500, '💰 500 Coins'),
                      ]
                          .map((e) => DropdownMenuItem<int>(
                                value: e.key,
                                child: Text(
                                  e.value,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() {
                            entryFeeCoins = val;
                            titleController.text = generateRoomTitle(
                                selectedMap, maxSlots, prizeCoins, entryFeeCoins);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // 7. IN-GAME ROOM ID & 8. PASSWORD
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: roomIdController,
                            style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
                            onChanged: (_) => setSheetState(() {}),
                            decoration: buildFieldDecoration(
                              label: 'IN-GAME ROOM ID *',
                              hint: 'e.g. 1234567',
                              error: isRoomIdEmpty ? 'Required' : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: passController,
                            style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
                            onChanged: (_) => setSheetState(() {}),
                            decoration: buildFieldDecoration(
                              label: 'PASSWORD *',
                              hint: 'e.g. 1234',
                              error: isPassEmpty ? 'Required' : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 9. PUBLISH ROOM BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPublishEnabled
                              ? const Color(0xFF1877F2)
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                          foregroundColor: isPublishEnabled
                              ? Colors.white
                              : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          elevation: isPublishEnabled ? 2 : 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: isPublishEnabled
                            ? () async {
                                final uid = currentUserId;
                                final name = currentUserName;
                                if (uid.isEmpty) return;

                                final hasActive = await _hasActiveRoom(uid);
                                if (hasActive) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            '⚠️ You already have an active room!'),
                                        backgroundColor: GamerTheme.accentOrange,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                  return;
                                }

                                await CoinOrAdPopup.show(
                                  context: context,
                                  actionName: 'Room Create',
                                  onConfirm: () async {
                                    final roomId = _generateUuid();
                                    final now = DateTime.now().toIso8601String();
                                    final startTime = DateTime.now()
                                        .add(const Duration(minutes: 15))
                                        .toIso8601String();
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
                                        'start_time': startTime,
                                        'entry_fee_coins': entryFeeCoins,
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
                                  },
                                );
                              }
                            : null,
                        child: Text(
                          'PUBLISH ROOM',
                          style: TextStyle(
                            color: isPublishEnabled
                                ? Colors.white
                                : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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

    final bool isBoosted = room.isBoosted;
    final bool isFeatured = room.isFeatured;
    final Color borderColor = isFeatured
        ? GamerTheme.accentOrange
        : isBoosted
            ? Colors.purpleAccent
            : (isJoined ? const Color(0xFF1877F2) : const Color(0xFFE4E6EB));
    final double borderWidth = isBoosted
        ? 2.0
        : (isJoined ? 1.5 : 1.0);

    return GestureDetector(
      onTap: () {
        if (isHost || isJoined) {
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
        joinRoom(room);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isBoosted
              ? (isFeatured
                  ? const Color(0xFFFFF7E6)
                  : const Color(0xFFF7F0FF))
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
          boxShadow: isBoosted
              ? [
                  BoxShadow(
                    color: borderColor.withOpacity(0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isBoosted)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isFeatured
                        ? [GamerTheme.accentOrange, Colors.orange.shade700]
                        : [Colors.purpleAccent, Colors.deepPurpleAccent],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isFeatured ? Icons.star_rounded : Icons.rocket_launch_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isFeatured ? '⭐ FEATURED ROOM' : '🚀 BOOSTED',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isJoined
                      ? const Color(0xFF1877F2)
                      : const Color(0xFFE4E6EB),
                  child: Text(initial,
                      style: TextStyle(
                          color: isJoined ? Colors.white : const Color(0xFF1C1E21),
                          fontWeight: FontWeight.bold)),
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
                    child: Column(children: [
                      Text(
                        room.entryFeeCoins == 0
                            ? 'FREE'
                            : '${room.entryFeeCoins} Coins',
                        style: TextStyle(
                            color: room.entryFeeCoins == 0
                                ? const Color(0xFF1877F2)
                                : const Color(0xFFFFA500),
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                      const Text('ENTRY FEE',
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
  final VoidCallback onDeleteRoom;

  const _InRoomBottomSheetContent({
    required this.room,
    required this.currentUserId,
    required this.currentUserName,
    required this.onJoinRoomRequested,
    required this.onLeaveRoom,
    required this.onDeleteRoom,
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
  bool _isUploadingProof = false;
  bool _isApproving = false;
  bool _isRejecting = false;

  StreamSubscription? _roomSub;
  GamerRoom? _liveRoom;

  GamerRoom get room => _liveRoom ?? widget.room;

  bool get isHost => room.hostId == widget.currentUserId;
  bool get isJoined =>
      room.joinedUserIds.contains(widget.currentUserId);
  bool get canAccess => isHost || isJoined;

  @override
  void initState() {
    super.initState();
    _updateRemainingTime();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _updateRemainingTime());
        _checkCompletedAutoDelete();
      }
    });

    _roomSub = SupabaseService.client
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('id', widget.room.id)
        .listen((rows) {
      if (rows.isNotEmpty && mounted) {
        try {
          final updated = GamerRoom.fromSupabase(
            Map<String, dynamic>.from(rows.first),
          );
          setState(() {
            _liveRoom = updated;
            _updateRemainingTime();
          });
          _checkCompletedAutoDelete();
        } catch (_) {}
      }
    });
  }

  bool _isAutoDeleting = false;

  Future<void> _checkCompletedAutoDelete() async {
    if (room.status.toLowerCase() != 'completed' || _isAutoDeleting) return;
    final cAt = room.completedAt;
    if (cAt == null) return;
    final deleteAt = cAt.add(const Duration(minutes: 5));
    final now = DateTime.now();
    if (now.isAfter(deleteAt) || deleteAt.difference(now).inSeconds <= 0) {
      _isAutoDeleting = true;
      _countdownTimer?.cancel();
      try {
        await SupabaseService.client.from('rooms').delete().eq('id', room.id);
      } catch (_) {}
      if (mounted) {
        Navigator.of(context).maybePop();
      }
    }
  }

  void _updateRemainingTime() {
    final now = DateTime.now();
    final rt = room.startTime;
    _remainingTime = rt.isAfter(now)
        ? rt.difference(now)
        : Duration.zero;
  }

  @override
  void dispose() {
    _roomSub?.cancel();
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

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied!'),
        backgroundColor: const Color(0xFF1877F2),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildRoomCredentialsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFC107), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.vpn_key_rounded,
                  color: Color(0xFFFF8F00), size: 18),
              SizedBox(width: 6),
              Text('ROOM CREDENTIALS',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Color(0xFF6D4C00),
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ROOM ID',
                        style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF65676B),
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      room.roomId.isEmpty ? '-' : room.roomId,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF050505)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded,
                    size: 18, color: Color(0xFF1877F2)),
                onPressed: room.roomId.isEmpty
                    ? null
                    : () => _copyToClipboard(room.roomId, 'Room ID'),
                tooltip: 'Copy Room ID',
              ),
            ],
          ),
          const Divider(height: 12, color: Color(0xFFFFD54F)),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PASSWORD',
                        style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF65676B),
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      room.roomPassword.isEmpty ? '-' : room.roomPassword,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF050505)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded,
                    size: 18, color: Color(0xFF1877F2)),
                onPressed: room.roomPassword.isEmpty
                    ? null
                    : () => _copyToClipboard(room.roomPassword, 'Password'),
                tooltip: 'Copy Password',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersList() {
    final players = room.joinedUsers;
    if (players.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCED0D4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded,
                  size: 16, color: Color(0xFF1877F2)),
              const SizedBox(width: 6),
              Text('PLAYERS (${players.length}/${room.total})',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Color(0xFF050505),
                      letterSpacing: 0.4)),
            ],
          ),
          const SizedBox(height: 8),
          ...players.map((p) {
            final pId = (p['id'] ?? '').toString();
            final pName = (p['name'] ?? 'Gamer').toString();
            final pPhoto = (p['photo'] ?? '').toString();
            final isThisHost = pId == room.hostId;
            final initial = pName.isNotEmpty ? pName[0].toUpperCase() : 'G';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFFE4E6EB),
                    backgroundImage:
                        pPhoto.isNotEmpty ? NetworkImage(pPhoto) : null,
                    child: pPhoto.isEmpty
                        ? Text(initial,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF050505)))
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(pName,
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (isThisHost)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1877F2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('HOST',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                  if (pId == widget.currentUserId && !isThisHost)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF31A24C),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('YOU',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // =========================================================================
  // FEATURE 1 (Option A): Host manually ends match with winner selection
  // =========================================================================
  Future<void> _showWinnerSelectionDialog(GamerRoom currentRoom) async {
    final players = currentRoom.joinedUsers;
    if (players.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No players joined yet to select as winner')),
      );
      return;
    }

    String? selectedWinnerId;
    String? selectedWinnerName;

    final selected = await showDialog<Map<String, String>>(
      context: context,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.emoji_events_rounded, color: Color(0xFFFFB300), size: 24),
                  SizedBox(width: 8),
                  Text('Declare Winner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select the match winner to distribute ${currentRoom.prize} Coins:',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF65676B)),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: players.length,
                        itemBuilder: (context, idx) {
                          final p = players[idx];
                          final pId = (p['id'] ?? '').toString();
                          final pName = (p['name'] ?? 'Player ${idx + 1}').toString();
                          final isSelected = selectedWinnerId == pId;
                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                selectedWinnerId = pId;
                                selectedWinnerName = pName;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFE8F5E9) : const Color(0xFFF0F2F5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF2E7D32) : const Color(0xFFCED0D4),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                    color: isSelected ? const Color(0xFF2E7D32) : const Color(0xFF65676B),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      pName,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 14,
                                        color: isSelected ? const Color(0xFF2E7D32) : const Color(0xFF050505),
                                      ),
                                    ),
                                  ),
                                  if (pId == currentRoom.hostId)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1877F2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('HOST', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF65676B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: selectedWinnerId == null
                      ? null
                      : () => Navigator.pop(dCtx, {'id': selectedWinnerId!, 'name': selectedWinnerName!}),
                  child: const Text('Confirm Winner', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null) {
      final winId = selected['id']!;
      final winName = selected['name']!;
      try {
        await SupabaseService.client.from('rooms').update({
          'status': 'reward_waiting',
          'reward_status': 'pending',
          'winner_id': winId,
          'winner_name': winName,
        }).eq('id', currentRoom.id);

        try {
          await SupabaseService.client.from('messages').insert({
            'room_id': currentRoom.id,
            'sender_id': 'system',
            'sender_name': 'ROOM BOT',
            'message': '🏁 Match ended by Host! Winner declared: $winName. Winner please upload winning screenshot to claim ${currentRoom.prize} coins! 🏆',
            'type': 'system',
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}

        try {
          await NotificationService().sendNotification(
            userId: winId,
            type: 'match_result',
            title: '🏆 Upload Proof to Claim Prize!',
            body: 'You were declared winner in ${currentRoom.title}! Upload result screenshot to receive ${currentRoom.prize} coins.',
            data: {'room_id': currentRoom.id},
            priority: 'high',
          );
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Winner declared: $winName! Awaiting proof screenshot.'),
              backgroundColor: const Color(0xFF2E7D32),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error ending match: $e'), backgroundColor: GamerTheme.redAccent),
          );
        }
      }
    }
  }

  // =========================================================================
  // FEATURE 2: Winner Proof Upload Card
  // =========================================================================
  Widget _buildWinnerProofUploadCard(GamerRoom currentRoom) {
    final bool isRejected = currentRoom.isProofRejected;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRejected ? const Color(0xFFFFEBEE) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRejected ? const Color(0xFFFF4655) : const Color(0xFFFFB300),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRejected ? Icons.warning_amber_rounded : Icons.emoji_events_rounded,
                color: isRejected ? const Color(0xFFFF4655) : const Color(0xFFFF8F00),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isRejected
                      ? 'PROOF REJECTED — RE-UPLOAD SCREENSHOT'
                      : 'MATCH ENDED — CLAIM YOUR PRIZE',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    color: isRejected ? const Color(0xFFFF4655) : const Color(0xFFB78103),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${currentRoom.prize} COINS',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (currentRoom.winnerName != null && currentRoom.winnerName!.isNotEmpty)
            Text(
              'Winner: ${currentRoom.winnerName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF050505)),
            ),
          const SizedBox(height: 4),
          const Text(
            'Instructions:\n• Full BGMI/FF result screen (WWCD/kills)\n• Player names must be visible\n• UID must be visible',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF65676B), height: 1.35),
          ),
          if (isRejected) ...[
            const SizedBox(height: 6),
            Text(
              'Attempts used: ${currentRoom.proofRejectCount}/3. Maximum 3 attempts before dispute.',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF4655)),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isUploadingProof
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.upload_file_rounded, size: 20),
              label: Text(
                _isUploadingProof ? 'UPLOADING & ANALYZING OCR...' : 'Upload Winning Screenshot',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: _isUploadingProof
                  ? null
                  : () async {
                      await CoinOrAdPopup.show(
                        context: context,
                        actionName: 'Proof Upload',
                        onConfirm: () => _handleUploadProof(currentRoom),
                      );
                    },
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // FEATURE 2 & 3: Proof Upload & OCR Verification Handler
  // =========================================================================
  Future<void> _handleUploadProof(GamerRoom currentRoom) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;

      setState(() => _isUploadingProof = true);

      final file = File(picked.path);
      final uploadedUrl = await SupabaseService.uploadFile(
        file: file,
        bucket: 'match_proofs',
        folder: 'tournament_rooms',
      );

      final proofUrl = uploadedUrl ??
          'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=800';

      // Update DB with proof submitted
      await SupabaseService.client.from('rooms').update({
        'status': 'proof_submitted',
        'win_proof_url': proofUrl,
        'proof_url': proofUrl,
        'win_proof_uploaded_at': DateTime.now().toIso8601String(),
        'reward_status': 'pending_approval',
        if (currentRoom.winnerId == null || currentRoom.winnerId!.isEmpty)
          'winner_id': widget.currentUserId,
        if (currentRoom.winnerName == null || currentRoom.winnerName!.isEmpty)
          'winner_name': widget.currentUserName,
      }).eq('id', currentRoom.id);

      try {
        await SupabaseService.client.from('messages').insert({
          'room_id': currentRoom.id,
          'sender_id': 'system',
          'sender_name': 'ROOM BOT',
          'message': '📸 Proof screenshot uploaded by ${widget.currentUserName}! Running AI OCR verification...',
          'type': 'system',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      // FEATURE 3: OCR Verification
      final targetWinner = currentRoom.winnerName ?? widget.currentUserName;
      WinProofValidationResult? ocrResult;
      try {
        ocrResult = await WinProofValidator.validate(
          imageFile: file,
          userId: currentRoom.winnerId ?? widget.currentUserId,
          accountIdName: targetWinner,
          roomId: currentRoom.id,
        );
      } catch (ocrErr) {
        debugPrint('OCR execution error: $ocrErr');
      }

      final ocrStatus = ocrResult?.status ?? 'uncertain';
      final ocrScore = ocrResult?.score ?? 0;
      final ocrText = (ocrResult?.fullOcrText ?? '').length > 400
          ? (ocrResult!.fullOcrText.substring(0, 400))
          : (ocrResult?.fullOcrText ?? '');

      await SupabaseService.client.from('rooms').update({
        'ocr_status': ocrStatus,
        'ocr_score': ocrScore,
        'ocr_text': ocrText,
      }).eq('id', currentRoom.id);

      // Check if high confidence OCR -> Auto Approve!
      if (ocrResult != null && (ocrResult.isVerified || ocrScore >= 3 || ocrResult.hasVictoryKeyword)) {
        final winId = currentRoom.winnerId ?? widget.currentUserId;
        final winName = currentRoom.winnerName ?? widget.currentUserName;
        await GamerRoomsScreen.distributePrizeAndComplete(
          room: currentRoom,
          winnerId: winId,
          winnerName: winName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 AI OCR Verified WWCD Screenshot! Prize auto-distributed!'),
              backgroundColor: Color(0xFF2E7D32),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        try {
          await SupabaseService.client.from('messages').insert({
            'room_id': currentRoom.id,
            'sender_id': 'system',
            'sender_name': 'ROOM BOT',
            'message': '🤖 AI OCR check complete (Score: $ocrScore/4). Waiting for Host approval.',
            'type': 'system',
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Screenshot uploaded! Awaiting Host review.'),
              backgroundColor: Color(0xFFFFB300),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Upload proof error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload proof: $e'), backgroundColor: GamerTheme.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingProof = false);
    }
  }

  // =========================================================================
  // FEATURE 4: Host Approval & Rejection Card
  // =========================================================================
  Widget _buildHostApprovalCard(GamerRoom currentRoom) {
    final proofUrl = currentRoom.winProofUrl ?? currentRoom.proofUrl ?? '';
    final winnerDisplay = currentRoom.winnerName ?? 'Winner';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1877F2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1877F2).withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: Color(0xFF1877F2), size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'HOST REVIEW — WINNER PROOF',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1877F2)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: currentRoom.ocrScore >= 3 ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: currentRoom.ocrScore >= 3 ? const Color(0xFF2E7D32) : const Color(0xFFFFB300),
                  ),
                ),
                child: Text(
                  'OCR: ${currentRoom.ocrScore}/4',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    color: currentRoom.ocrScore >= 3 ? const Color(0xFF2E7D32) : const Color(0xFFB78103),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Winner: $winnerDisplay • Prize: ${currentRoom.prize} Coins',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF050505)),
          ),
          if (currentRoom.ocrStatus.isNotEmpty && currentRoom.ocrStatus != 'none')
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'AI Scan: ${currentRoom.ocrStatus.toUpperCase()}',
                style: TextStyle(
                  fontSize: 11,
                  color: currentRoom.ocrScore >= 3 ? const Color(0xFF2E7D32) : const Color(0xFF65676B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (proofUrl.isNotEmpty)
            GestureDetector(
              onTap: () => _showFullScreenImage(proofUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.network(
                      proofUrl,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 140,
                        color: const Color(0xFFE4E6EB),
                        child: const Center(
                          child: Icon(Icons.broken_image_rounded, color: Color(0xFF65676B)),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Tap to View Fullscreen', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (isHost)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GamerTheme.redAccent,
                      side: const BorderSide(color: GamerTheme.redAccent, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isRejecting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: GamerTheme.redAccent))
                        : const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('REJECT', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _isRejecting ? null : () => _handleRejectProof(currentRoom),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isApproving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('APPROVE', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _isApproving ? null : () => _handleApproveProof(currentRoom),
                  ),
                ),
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F3FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⏳ Host is reviewing the proof. Prize will be distributed upon approval.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: Color(0xFF1877F2), fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleApproveProof(GamerRoom currentRoom) async {
    setState(() => _isApproving = true);
    try {
      final winId = currentRoom.winnerId ?? widget.currentUserId;
      final winName = currentRoom.winnerName ?? widget.currentUserName;
      await GamerRoomsScreen.distributePrizeAndComplete(
        room: currentRoom,
        winnerId: winId,
        winnerName: winName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🏆 Match approved! ${currentRoom.prize} coins distributed to $winName!'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approval error: $e'), backgroundColor: GamerTheme.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  Future<void> _handleRejectProof(GamerRoom currentRoom) async {
    final newCount = currentRoom.proofRejectCount + 1;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Proof?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          newCount >= 3
              ? 'This will be the 3rd rejection! The match will be escalated to Admin Dispute.'
              : 'Reject this proof? The winner can re-upload up to 3 times ($newCount/3 used).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GamerTheme.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isRejecting = true);
    try {
      if (newCount >= 3) {
        await SupabaseService.client.from('rooms').update({
          'status': 'disputed',
          'disputed': true,
          'dispute_reason': 'Proof rejected 3 times by host. Escalated to admin review.',
          'proof_reject_count': newCount,
          'disputed_at': DateTime.now().toIso8601String(),
        }).eq('id', currentRoom.id);

        try {
          await SupabaseService.client.from('reports').insert({
            'reporter_id': widget.currentUserId.isNotEmpty ? widget.currentUserId : null,
            'reporter_username': widget.currentUserName.isNotEmpty ? widget.currentUserName : 'Host',
            'target_type': 'match',
            'target_id': currentRoom.id,
            'target_content': 'Proof rejected 3 times by host. Escalated to admin review.',
            'reason': 'Proof rejected 3 times by host',
            'status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}

        try {
          await SupabaseService.client.from('messages').insert({
            'room_id': currentRoom.id,
            'sender_id': 'system',
            'sender_name': 'ROOM BOT',
            'message': '⚠️ Proof rejected 3 times. Match escalated to Admin Dispute.',
            'type': 'system',
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      } else {
        await SupabaseService.client.from('rooms').update({
          'status': 'proof_rejected',
          'reward_status': 'rejected',
          'proof_reject_count': newCount,
        }).eq('id', currentRoom.id);

        try {
          await SupabaseService.client.from('messages').insert({
            'room_id': currentRoom.id,
            'sender_id': 'system',
            'sender_name': 'ROOM BOT',
            'message': '❌ Winning proof was rejected by Host. Winner please re-upload clear screenshot (Attempt $newCount/3).',
            'type': 'system',
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}

        if (currentRoom.winnerId != null) {
          try {
            await NotificationService().sendNotification(
              userId: currentRoom.winnerId!,
              type: 'match_result',
              title: 'Proof Rejected',
              body: 'Your match screenshot was rejected by the host. Please re-upload.',
              data: {'room_id': currentRoom.id},
            );
          } catch (_) {}
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Proof rejected ($newCount/3)'), backgroundColor: GamerTheme.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reject error: $e'), backgroundColor: GamerTheme.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isRejecting = false);
    }
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: Colors.black,
                  child: const Center(
                    child: Text('Failed to load image', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // FEATURE 7: Dispute System Dialog
  // =========================================================================
  Future<void> _showDisputeDialog(GamerRoom currentRoom) async {
    final reasonController = TextEditingController();
    String? disputeProofUrl;
    bool isUploadingDisputeProof = false;

    await showDialog(
      context: context,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (context, setDState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Row(
                children: [
                  Icon(Icons.report_problem_rounded, color: Color(0xFFFF4655), size: 22),
                  SizedBox(width: 8),
                  Text('Raise Dispute', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Report an issue with this match (e.g. hacker, fake proof, no-show, wrong winner). Admin will review.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF65676B)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter dispute reason in detail...',
                        filled: true,
                        fillColor: const Color(0xFFF0F2F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1877F2),
                        side: const BorderSide(color: Color(0xFF1877F2)),
                      ),
                      icon: isUploadingDisputeProof
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.attach_file_rounded, size: 18),
                      label: Text(
                        disputeProofUrl != null ? 'Proof Attached ✓' : 'Attach Proof Image',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: isUploadingDisputeProof
                          ? null
                          : () async {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                              if (picked == null) return;
                              setDState(() => isUploadingDisputeProof = true);
                              try {
                                final url = await SupabaseService.uploadFile(
                                  file: File(picked.path),
                                  bucket: 'match_proofs',
                                  folder: 'disputes',
                                );
                                setDState(() => disputeProofUrl = url);
                              } catch (_) {}
                              setDState(() => isUploadingDisputeProof = false);
                            },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF65676B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4655),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final reason = reasonController.text.trim();
                    if (reason.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please describe the reason for dispute')),
                      );
                      return;
                    }
                    Navigator.pop(dCtx);
                    try {
                      await SupabaseService.client.from('rooms').update({
                        'status': 'disputed',
                        'disputed': true,
                        'disputed_by': widget.currentUserId,
                        'disputed_by_name': widget.currentUserName,
                        'dispute_reason': reason,
                        'dispute_proof_url': disputeProofUrl,
                        'disputed_at': DateTime.now().toIso8601String(),
                      }).eq('id', currentRoom.id);

                      // Also insert into reports table for Admin Panel visibility (Issue #1)
                      try {
                        await SupabaseService.client.from('reports').insert({
                          'reporter_id': widget.currentUserId.isNotEmpty ? widget.currentUserId : null,
                          'reporter_username': widget.currentUserName.isNotEmpty ? widget.currentUserName : 'Gamer',
                          'target_type': 'match',
                          'target_id': currentRoom.id,
                          'target_content': reason,
                          'reason': reason,
                          'status': 'pending',
                          'created_at': DateTime.now().toIso8601String(),
                        });
                      } catch (reportErr) {
                        debugPrint('[GamerRoomsScreen] reports insert error: $reportErr');
                      }

                      try {
                        await SupabaseService.client.from('messages').insert({
                          'room_id': currentRoom.id,
                          'sender_id': 'system',
                          'sender_name': 'ROOM BOT',
                          'message': '⚠️ Dispute raised by ${widget.currentUserName}: "$reason". Admin will review.',
                          'type': 'system',
                          'created_at': DateTime.now().toIso8601String(),
                        });
                      } catch (_) {}

                      for (final uid in currentRoom.joinedUserIds) {
                        if (uid.isNotEmpty && uid != 'guest') {
                          try {
                            await NotificationService().sendNotification(
                              userId: uid,
                              type: 'tournament_update',
                              title: '⚠️ Dispute Raised',
                              body: 'Dispute raised in ${currentRoom.title}. Admin will review.',
                              data: {'room_id': currentRoom.id},
                            );
                          } catch (_) {}
                        }
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Dispute submitted! Admin will investigate.'),
                            backgroundColor: Color(0xFFFF4655),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Dispute submission error: $e'), backgroundColor: GamerTheme.redAccent),
                        );
                      }
                    }
                  },
                  child: const Text('Submit Dispute', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentRoom = room;
    final isH = currentRoom.hostId == widget.currentUserId;
    final isJ = currentRoom.joinedUserIds.contains(widget.currentUserId);
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
                        Text(currentRoom.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Host: ${currentRoom.hostName} • ${currentRoom.map}',
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
                        'Prize: ${currentRoom.prize} Coins • Entry: ${currentRoom.entryFeeCoins == 0 ? "FREE" : "${currentRoom.entryFeeCoins} Coins"} • Slots: ${currentRoom.filled}/${currentRoom.total}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: currentRoom.isCompleted
                            ? const Color(0xFFE8F5E9)
                            : currentRoom.isDisputed
                                ? const Color(0xFFFFEBEE)
                                : const Color(0xFFE7F3FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        currentRoom.isCompleted
                            ? 'COMPLETED 🏆'
                            : currentRoom.isDisputed
                                ? '⚠️ DISPUTED (ADMIN REVIEW)'
                                : currentRoom.isProofRejected
                                    ? '❌ PROOF REJECTED'
                                    : currentRoom.isProofSubmitted
                                        ? '⏳ PROOF UNDER REVIEW'
                                        : currentRoom.isRewardWaiting
                                            ? '🏁 MATCH ENDED — CLAIM PRIZE'
                                            : currentRoom.isInProgress
                                                ? '🔥 MATCH IN PROGRESS'
                                                : _formatDuration(_remainingTime),
                        style: TextStyle(
                            color: currentRoom.isCompleted
                                ? const Color(0xFF2E7D32)
                                : currentRoom.isDisputed
                                    ? const Color(0xFFFF4655)
                                    : const Color(0xFF1877F2),
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (access) ...[
                      _buildRoomCredentialsCard(),
                      const SizedBox(height: 12),
                      _buildPlayersList(),
                      const SizedBox(height: 12),
                    ],

                    // Lifecycle Status Banners & Actions
                    if (currentRoom.isCompleted)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF2E7D32), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.emoji_events_rounded,
                                color: Color(0xFF2E7D32), size: 24),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '🏆 MATCH COMPLETED — Winner: ${currentRoom.winnerName ?? "Player"} (+${currentRoom.prize} Coins)',
                                style: const TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (currentRoom.isDisputed)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFFF4655), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.report_problem_rounded,
                                    color: Color(0xFFFF4655), size: 20),
                                SizedBox(width: 8),
                                Text('⚠️ MATCH DISPUTED — ESCALATED TO ADMIN',
                                    style: TextStyle(
                                        color: Color(0xFFFF4655),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ],
                            ),
                            if (currentRoom.disputeReason != null &&
                                currentRoom.disputeReason!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Reason: ${currentRoom.disputeReason}',
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF050505))),
                            ],
                          ],
                        ),
                      ),

                    if (currentRoom.isRewardWaiting ||
                        currentRoom.isProofRejected)
                      _buildWinnerProofUploadCard(currentRoom),

                    if (currentRoom.isProofSubmitted)
                      _buildHostApprovalCard(currentRoom),

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
                            .eq('room_id', currentRoom.id)
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
                                  msg['type'] == 'system' ||
                                  msg['type'] == 'system_reward';
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
                                          textAlign: TextAlign.center,
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
                                'room_id': currentRoom.id,
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
                        child: Text(currentRoom.entryFeeCoins == 0
                            ? 'JOIN ROOM - FREE'
                            : 'JOIN ROOM - ${currentRoom.entryFeeCoins} COINS'),
                      ),
                    const SizedBox(height: 12),
                    if (isH && currentRoom.isInProgress)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('END MATCH — DECLARE WINNER',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13.5)),
                        onPressed: () =>
                            _showWinnerSelectionDialog(currentRoom),
                      )
                    else if (isH && !currentRoom.isCompleted && currentRoom.isActive)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1877F2),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 46),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
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
                                    'start_time':
                                        DateTime.now().toIso8601String(),
                                  }).eq('id', currentRoom.id);
                                  try {
                                    await SupabaseService.client
                                        .from('messages')
                                        .insert({
                                      'room_id': currentRoom.id,
                                      'sender_id': 'system',
                                      'sender_name': 'ROOM BOT',
                                      'message':
                                          '🏁 Match has started! Good luck 🎮',
                                      'type': 'system',
                                      'created_at': DateTime.now()
                                          .toIso8601String(),
                                    });
                                  } catch (_) {}
                                } catch (_) {}
                                if (mounted) {
                                  setState(
                                      () => _isStartingMatch = false);
                                }
                              },
                      ),
                    if (access && !currentRoom.isCompleted)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: TextButton.icon(
                          onPressed: () => _showDisputeDialog(currentRoom),
                          icon: const Icon(Icons.report_problem_outlined,
                              size: 16, color: Color(0xFF65676B)),
                          label: const Text('Raise Dispute / Report Issue',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF65676B))),
                        ),
                      ),
                    if (currentRoom.status.toLowerCase() == 'completed')
                      Builder(builder: (context) {
                        final cAt = currentRoom.completedAt ?? DateTime.now();
                        final deleteAt = cAt.add(const Duration(minutes: 5));
                        final diff = deleteAt.difference(DateTime.now());
                        final totalSecs = diff.isNegative ? 0 : diff.inSeconds;
                        final m = totalSecs ~/ 60;
                        final s = totalSecs % 60;
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F2F5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCED0D4)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.timer_outlined,
                                  size: 18, color: Color(0xFF65676B)),
                              const SizedBox(width: 8),
                              Text(
                                '🕐 Room will auto-delete in: ${m}m ${s}s',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF050505),
                                ),
                              ),
                            ],
                          ),
                        );
                      })
                    else if (isH)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: GamerTheme.redAccent,
                            side: const BorderSide(
                                color: GamerTheme.redAccent, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            minimumSize: const Size(double.infinity, 0),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: widget.onDeleteRoom,
                          icon: const Icon(Icons.delete_forever_rounded,
                              size: 18, color: GamerTheme.redAccent),
                          label: const Text(
                            'DELETE ROOM',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: GamerTheme.redAccent),
                          ),
                        ),
                      ),
                    if (isJ && !isH)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 46),
                          foregroundColor: GamerTheme.redAccent,
                          side: const BorderSide(
                              color: GamerTheme.redAccent, width: 1.2),
                        ),
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