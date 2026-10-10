import 'dart:async';
import 'dart:io';
import '../services/supabase_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../constants/gamer_theme.dart';
import '../models/tournament_room_model.dart';
import '../models/coin_wallet_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/tournament_service.dart';
import '../services/coin_wallet_service.dart';
import '../services/ad_free_service.dart';
import '../services/supabase_service.dart';
import '../services/win_proof_validator.dart';
import 'coin_store_screen.dart';
import '../widgets/coin_history_sheet.dart';

/// =========================================================================
/// 1. DATA MODEL: GamerRoom
/// =========================================================================
class GamerRoom {
  final String id;
  final String title;
  final String hostId;
  final String hostName;
  final String map;
  final String game;
  final int prize;
  final String entryFee;
  final int total;
  final int filled;
  final List<String> joinedUserIds;
  final List<Map<String, dynamic>> joinedUsers;
  final String roomIdCode;
  final String password;
  final String status;
  final DateTime createdAt;
  final DateTime startTime;
  final String rewardStatus;
  final String? winnerId;
  final String? winnerName;
  final String prizeSource;
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
    required this.title,
    required this.hostId,
    required this.hostName,
    required this.map,
    required this.game,
    required this.prize,
    required this.entryFee,
    required this.total,
    required this.filled,
    required this.joinedUserIds,
    required this.joinedUsers,
    required this.roomIdCode,
    required this.password,
    required this.status,
    required this.createdAt,
    required this.startTime,
    this.rewardStatus = 'idle',
    this.winnerId,
    this.winnerName,
    this.prizeSource = 'application',
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
  });

  bool get isFull => filled >= total;
  bool get isCompleted => status.toLowerCase() == 'completed' || rewardStatus.toLowerCase() == 'sent';
  bool get isDisputed => disputed || status.toLowerCase() == 'disputed' || status.toLowerCase() == 'under_review';
  bool get isUnderReview => status.toLowerCase() == 'under_review' || isDisputed;
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
          ((proofUrl != null && proofUrl!.isNotEmpty) || (winProofUrl != null && winProofUrl!.isNotEmpty)));
  bool get isInProgress => !isCompleted && !isRewardWaiting && !isDisputed && !isProofRejected && (status.toUpperCase() == 'IN_PROGRESS' || status.toUpperCase() == 'STARTED' || status.toUpperCase() == 'MATCH_STARTED');
  bool get isActive => !isCompleted && !isRewardWaiting && !isDisputed && !isProofRejected && (status.toLowerCase() == 'active' || status.toUpperCase() == 'OPEN');
  bool get isExpiredCompleted {
    if (!isCompleted || completedAt == null) return false;
    return DateTime.now().difference(completedAt!).inMinutes >= 5;
  }

  factory GamerRoom.fromFirestore(SupaDoc doc) => GamerRoom.fromSupabase(doc);

  factory GamerRoom.fromSupabase(SupaDoc doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final id = doc.id;
    // Rooms table columns: id, host_id, game, mode, room_id, room_password,
    // prize_pool, total_slots, filled_slots, status, created_at
    final title = (data['title'] ?? data['game'] ?? 'Custom Match').toString();
    final hostId = (data['host_id'] ?? data['hostId'] ?? '').toString();
    String hostName = (data['hostName'] ?? data['host_name'] ?? data['host'] ?? data['hostUsername'] ?? '').toString().trim();
    if (hostName.isEmpty || hostName.toLowerCase() == 'host') {
      if (data['host_username'] != null && data['host_username'].toString().trim().isNotEmpty) {
        hostName = data['host_username'].toString().trim();
      } else if (data['host_display_name'] != null && data['host_display_name'].toString().trim().isNotEmpty) {
        hostName = data['host_display_name'].toString().trim();
      }
    }
    if (hostName.isEmpty || hostName.toLowerCase() == 'host') {
      final pNames = Map<String, dynamic>.from(data['joinedPlayerNames'] ?? {});
      if (pNames.containsKey(hostId) && pNames[hostId].toString().trim().isNotEmpty) {
        hostName = pNames[hostId].toString().trim();
      }
    }
    if (hostName.isEmpty) hostName = 'Host';

    final map = (data['map'] ?? data['mode'] ?? 'Erangel').toString();
    final game = (data['game'] ?? data['gameType'] ?? data['gameName'] ?? 'BGMI').toString();

    int prize = 500;
    if (data['prize'] is num) {
      prize = (data['prize'] as num).toInt();
    } else if (data['prizePoolCoins'] is num) {
      prize = (data['prizePoolCoins'] as num).toInt();
    } else if (data['prize_pool'] is num) {
      prize = (data['prize_pool'] as num).toInt();
    }

    const entryFee = 'FREE';

    int total = 2;
    if (data['total'] is num) {
      total = (data['total'] as num).toInt();
    } else if (data['totalSlots'] is num) {
      total = (data['totalSlots'] as num).toInt();
    } else if (data['maxSlots'] is num) {
      total = (data['maxSlots'] as num).toInt();
    } else if (data['total_slots'] is num) {
      total = (data['total_slots'] as num).toInt();
    }

    final List<String> joinedUserIds = List<String>.from(
        data['joinedUserIds'] ?? data['joinedPlayers'] ?? []);

    final List<Map<String, dynamic>> joinedUsers = [];
    if (data['joinedUsers'] is List) {
      for (final item in (data['joinedUsers'] as List)) {
        if (item is Map) {
          joinedUsers.add(Map<String, dynamic>.from(item));
        }
      }
    }

    if (joinedUsers.isEmpty && joinedUserIds.isNotEmpty) {
      final pNames = Map<String, dynamic>.from(data['joinedPlayerNames'] ?? {});
      for (final uid in joinedUserIds) {
        joinedUsers.add({
          'id': uid,
          'name': pNames[uid] ?? (uid == hostId ? hostName : 'Player'),
          'photo': '',
          'joinedAt': data['createdAt'] ?? SupaTime.now(),
        });
      }
    }

    int filled = 1;
    if (data['filled'] is num) {
      filled = (data['filled'] as num).toInt();
    } else if (data['currentSlots'] is num) {
      filled = (data['currentSlots'] as num).toInt();
    } else if (data['filled_slots'] is num) {
      filled = (data['filled_slots'] as num).toInt();
    } else if (joinedUsers.isNotEmpty) {
      filled = joinedUsers.length;
    } else if (joinedUserIds.isNotEmpty) {
      filled = joinedUserIds.length;
    }

    final roomIdCode =
        (data['roomIdCode'] ?? data['room_id'] ?? data['roomId'] ?? '').toString();
    final password =
        (data['password'] ?? data['room_password'] ?? '').toString();
    final status = (data['status'] ?? 'active').toString();
    final rewardStatus = (data['rewardStatus'] ??
            (status.toLowerCase() == 'completed' ? 'sent' : 'idle'))
        .toString();
    final winnerId = data['winnerId']?.toString() ?? data['winner_id']?.toString();
    final winnerName = data['winnerName']?.toString() ?? data['winner_name']?.toString();
    final prizeSource = (data['prizeSource'] ?? 'application').toString();
    final ocrStatus = (data['ocrStatus'] ?? 'none').toString();
    final ocrText = (data['ocrText'] ?? '').toString();
    final int ocrScore = (data['ocrScore'] is num) ? (data['ocrScore'] as num).toInt() : 0;
    final winProofUrl = data['winProofUrl']?.toString() ??
        data['win_proof_url']?.toString() ??
        data['proofUrl']?.toString() ??
        data['proof_url']?.toString();
    final proofUrl = data['proofUrl']?.toString() ??
        data['proof_url']?.toString() ??
        winProofUrl;

    DateTime? winProofUploadedAt;
    if (data['winProofUploadedAt'] is SupaTime) {
      winProofUploadedAt = (data['winProofUploadedAt'] as SupaTime).toDate();
    } else if (data['winProofUploadedAt'] is String) {
      winProofUploadedAt = DateTime.tryParse(data['winProofUploadedAt']);
    } else if (data['win_proof_uploaded_at'] is String) {
      winProofUploadedAt = DateTime.tryParse(data['win_proof_uploaded_at']);
    }

    DateTime? completedAt;
    if (data['completedAt'] is SupaTime) {
      completedAt = (data['completedAt'] as SupaTime).toDate();
    } else if (data['completedAt'] is String) {
      completedAt = DateTime.tryParse(data['completedAt']);
    } else if (data['completed_at'] is String) {
      completedAt = DateTime.tryParse(data['completed_at']);
    }

    DateTime? autoApproveAt;
    if (data['autoApproveAt'] is SupaTime) {
      autoApproveAt = (data['autoApproveAt'] as SupaTime).toDate();
    } else if (data['autoApproveAt'] is String) {
      autoApproveAt = DateTime.tryParse(data['autoApproveAt']);
    }

    final bool disputed = data['disputed'] == true ||
        status.toLowerCase() == 'disputed' ||
        status.toLowerCase() == 'under_review';
    final String? disputedBy = data['disputedBy']?.toString();
    final String? disputedByName = data['disputedByName']?.toString();
    final String? disputeReason = data['disputeReason']?.toString();
    final String? disputeProofUrl = data['disputeProofUrl']?.toString();
    DateTime? disputedAt;
    if (data['disputedAt'] is SupaTime) {
      disputedAt = (data['disputedAt'] as SupaTime).toDate();
    } else if (data['disputedAt'] is String) {
      disputedAt = DateTime.tryParse(data['disputedAt']);
    }

    DateTime created = DateTime.now();
    if (data['createdAt'] is SupaTime) {
      created = (data['createdAt'] as SupaTime).toDate();
    } else if (data['created_at'] is String) {
      created = DateTime.tryParse(data['created_at']) ?? created;
    }

    DateTime start = DateTime.now().add(const Duration(minutes: 15));
    if (data['startTime'] is SupaTime) {
      start = (data['startTime'] as SupaTime).toDate();
    } else if (data['startTime'] is String) {
      start = DateTime.tryParse(data['startTime']) ?? start;
    } else if (data['start_time'] is String) {
      start = DateTime.tryParse(data['start_time']) ?? start;
    }

    return GamerRoom(
      id: id,
      title: title,
      hostId: hostId,
      hostName: hostName,
      map: map,
      game: game,
      prize: prize,
      entryFee: entryFee,
      total: total > 0 ? total : 2,
      filled: filled.clamp(0, total > 0 ? total : 2),
      joinedUserIds: joinedUserIds,
      joinedUsers: joinedUsers,
      roomIdCode: roomIdCode,
      password: password,
      status: status,
      createdAt: created,
      startTime: start,
      rewardStatus: rewardStatus,
      winnerId: winnerId,
      winnerName: winnerName,
      prizeSource: prizeSource,
      ocrStatus: ocrStatus,
      ocrText: ocrText,
      ocrScore: ocrScore,
      proofUrl: proofUrl,
      winProofUrl: winProofUrl,
      winProofUploadedAt: winProofUploadedAt,
      completedAt: completedAt,
      autoApproveAt: autoApproveAt,
      disputed: disputed,
      disputedBy: disputedBy,
      disputedByName: disputedByName,
      disputeReason: disputeReason,
      disputeProofUrl: disputeProofUrl,
      disputedAt: disputedAt,
    );
  }
}

/// =========================================================================
/// 2. MAIN SCREEN: GamerRoomsScreen
/// =========================================================================
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

  void _watchRewardedAdForCoins() {
    if (_isWatchingAdFromRooms) return;
    final uid = currentUserId;
    if (uid.isEmpty) return;

    setState(() => _isWatchingAdFromRooms = true);
    int remainingSeconds = 5;
    Timer? adTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          adTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (remainingSeconds > 1) {
              setDialogState(() => remainingSeconds--);
            } else {
              t.cancel();
              Navigator.pop(dialogCtx);
              CoinWalletService().rewardAdCoins(uid);
              if (mounted) {
                setState(() => _isWatchingAdFromRooms = false);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF1877F2),
                    content: Row(
                      children: [
                        Text('💰', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 10),
                        Text(
                          '+50 G-Coins added for watching sponsored ad!',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            }
          });

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE7F3FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF1877F2), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'REWARDED SPONSOR AD',
                    style: TextStyle(
                      color: Color(0xFF1877F2),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${remainingSeconds}s',
                    style: const TextStyle(color: Color(0xFF050505), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 130,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE7F3FF), Color(0xFFF0F2F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFCED0D4)),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sports_esports_rounded, color: Color(0xFF1877F2), size: 44),
                        SizedBox(height: 8),
                        Text(
                          'Sponsored Gaming Partner',
                          style: TextStyle(color: Color(0xFF050505), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Watch 5s ad to earn +50 G-Coins...',
                          style: TextStyle(color: Color(0xFF65676B), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (5 - remainingSeconds) / 5.0,
                  backgroundColor: const Color(0xFFE4E6EB),
                  color: const Color(0xFF1877F2),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      adTimer?.cancel();
      if (mounted) setState(() => _isWatchingAdFromRooms = false);
    });
  }

  final Map<String, String> _hostNameCache = {};

  Future<void> _ensureHostNameLoaded(String hostId) async {
    if (hostId.isEmpty ||
        (_hostNameCache.containsKey(hostId) &&
            _hostNameCache[hostId]!.toLowerCase() != 'host')) return;
    try {
      final doc = await SupaStore.instance.collection('users').doc(hostId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final username = (data['username'] ??
                data['displayName'] ??
                data['display_name'] ??
                data['name'] ??
                data['bgmiId'])
            ?.toString()
            .trim() ??
            '';
        if (username.isNotEmpty && username.toLowerCase() != 'host') {
          _hostNameCache[hostId] = username;
          if (mounted) setState(() {});
          return;
        }
      }
      final tQuery = await SupaStore.instance
          .collection('tournament_rooms')
          .where('hostId', isEqualTo: hostId)
          .limit(1)
          .get();
      if (tQuery.docs.isNotEmpty) {
        final tData = tQuery.docs.first.data() ?? {};
        final tHost =
            (tData['hostName'] ?? tData['host'] ?? tData['hostUsername'])
                    ?.toString()
                    .trim() ??
                '';
        if (tHost.isNotEmpty && tHost.toLowerCase() != 'host') {
          _hostNameCache[hostId] = tHost;
          if (mounted) setState(() {});
          return;
        }
      }
    } catch (_) {}
    if (!_hostNameCache.containsKey(hostId)) {
      _hostNameCache[hostId] = 'Host';
    }
  }

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
      final snap = await SupaStore.instance
          .collection('rooms')
          .where('status', isEqualTo: 'completed')
          .get();

      for (final doc in snap.docs) {
        final data = doc.data() ?? {};
        DateTime? completedAt;
        if (data['completedAt'] is SupaTime) {
          completedAt = (data['completedAt'] as SupaTime).toDate();
        } else if (data['completedAt'] is String) {
          completedAt = DateTime.tryParse(data['completedAt']);
        } else if (data['completed_at'] is String) {
          completedAt = DateTime.tryParse(data['completed_at']);
        }
        if (completedAt != null && now.difference(completedAt).inMinutes >= 5) {
          await doc.reference.delete().catchError((_) {});
          SupaStore.instance
              .collection('tournament_rooms')
              .doc(doc.id)
              .delete()
              .catchError((_) {});
        }
      }
    } catch (_) {}
  }

  Future<void> _checkAutoApproveRooms() async {
    try {
      final now = DateTime.now();
      final snap = await SupaStore.instance
          .collection('rooms')
          .where('status', isEqualTo: 'reward_waiting')
          .get();

      for (final doc in snap.docs) {
        final data = doc.data() ?? {};
        if (data['disputed'] == true || data['status'] == 'disputed') continue;

        DateTime? autoApproveAt;
        if (data['autoApproveAt'] is SupaTime) {
          autoApproveAt = (data['autoApproveAt'] as SupaTime).toDate();
        } else if (data['autoApproveAt'] is String) {
          autoApproveAt = DateTime.tryParse(data['autoApproveAt']);
        }

        if (autoApproveAt == null && data['winProofUploadedAt'] != null) {
          if (data['winProofUploadedAt'] is SupaTime) {
            autoApproveAt = (data['winProofUploadedAt'] as SupaTime)
                .toDate()
                .add(const Duration(minutes: 15));
          } else if (data['winProofUploadedAt'] is String) {
            final p = DateTime.tryParse(data['winProofUploadedAt']);
            if (p != null) autoApproveAt = p.add(const Duration(minutes: 15));
          }
        }

        if (autoApproveAt != null && now.isAfter(autoApproveAt)) {
          final room = GamerRoom.fromSupabase(doc);
          await _executeAutoApprove(room);
        }
      }
    } catch (_) {}
  }

  Future<void> _executeAutoApprove(GamerRoom room) async {
    final roomRef = SupaStore.instance.collection('rooms').doc(room.id);
    try {
      final snap = await roomRef.get();
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      if (data['rewardStatus'] == 'sent' ||
          data['status'] == 'completed' ||
          data['disputed'] == true) {
        return;
      }

      String resolvedWinnerId =
          (data['winnerId'] ?? room.winnerId ?? '').toString();
      String resolvedWinnerName =
          (data['winnerName'] ?? room.winnerName ?? '').toString();

      if (resolvedWinnerId.isEmpty || resolvedWinnerId == 'guest') {
        if (room.joinedUsers.length > 1) {
          resolvedWinnerId = (room.joinedUsers[1]['id'] ?? '').toString();
          resolvedWinnerName =
              (room.joinedUsers[1]['name'] ?? 'Winner').toString();
        } else if (room.joinedUserIds.length > 1) {
          resolvedWinnerId = room.joinedUserIds[1];
          resolvedWinnerName = 'Winner';
        } else if (room.joinedUserIds.isNotEmpty) {
          resolvedWinnerId = room.joinedUserIds.first;
          resolvedWinnerName = 'Winner';
        }
      }
      if (resolvedWinnerName.isEmpty) resolvedWinnerName = 'Winner';

      final int prize = room.prize;
      final SupaDocRef winnerRef =
          SupaStore.instance.collection('users').doc(resolvedWinnerId);

      await SupaStore.instance.runTransaction((transaction) async {
        final winnerSnap = await transaction.get(winnerRef);
        final txRoomSnap = await transaction.get(roomRef);

        final txRoomData = txRoomSnap.data() as Map<String, dynamic>? ?? {};
        if (txRoomData['rewardStatus'] == 'sent' ||
            txRoomData['disputed'] == true) {
          return;
        }

        int currentCoins = 0;
        int currentWins = 0;
        int currentWinnings = 0;

        if (winnerSnap.exists) {
          final winnerData =
              winnerSnap.data() as Map<String, dynamic>? ?? {};
          final rawCoins = winnerData['gCoins'] ?? winnerData['coins'];
          if (rawCoins is num) currentCoins = rawCoins.toInt();
          final rawWins = winnerData['wins'];
          if (rawWins is num) currentWins = rawWins.toInt();
          final rawWinnings = winnerData['totalWinnings'];
          if (rawWinnings is num) currentWinnings = rawWinnings.toInt();
        }

        final int updatedCoins = currentCoins + prize;

        if (winnerSnap.exists) {
          transaction.update(winnerRef, {
            'gCoins': updatedCoins,
            'coins': updatedCoins,
            'totalWinnings': currentWinnings + prize,
            'wins': currentWins + 1,
            'lastRewardAt': SupaField.serverTimestamp(),
          });
        } else {
          transaction.set(winnerRef, {
            'gCoins': updatedCoins,
            'coins': updatedCoins,
            'totalWinnings': prize,
            'wins': 1,
            'lastRewardAt': SupaField.serverTimestamp(),
          });
        }

        final SupaDocRef txRef =
            SupaStore.instance.collection('transactions').doc();
        final String txId = txRef.id;
        final txLogData = {
          'id': txId,
          'userId': resolvedWinnerId,
          'amount': prize,
          'type': 'win_reward',
          'from': 'app_auto_approved',
          'to': resolvedWinnerId,
          'title': 'Match Victory Reward 🏆 (Auto-Approved)',
          'description':
              'Won ${room.game} Match: ${room.title} - Auto-approved after 15m without dispute',
          'roomId': room.id,
          'approvedBy': 'system_auto_timer',
          'prizeSource': 'application',
          'status': 'completed',
          'winProofUrl': room.winProofUrl ?? room.proofUrl,
          'createdAt': SupaField.serverTimestamp(),
          'timestamp': SupaField.serverTimestamp(),
        };
        transaction.set(txRef, txLogData);
        transaction.set(
            SupaStore.instance.collection('coin_transactions').doc(txId),
            txLogData);

        transaction.update(roomRef, {
          'rewardStatus': 'sent',
          'status': 'completed',
          'winnerId': resolvedWinnerId,
          'winnerName': resolvedWinnerName,
          'prizeSource': 'application',
          'rewardSentAt': SupaField.serverTimestamp(),
          'isCompleted': true,
          'isLive': false,
          'completedAt': SupaField.serverTimestamp(),
        });

        final SupaDocRef msgRef = roomRef.collection('messages').doc();
        transaction.set(msgRef, {
          'type': 'system_reward',
          'message':
              '🏆 REWARD AUTO-SENT! 15 minutes passed with no dispute. $prize Coins sent to $resolvedWinnerName from App!',
          'timestamp': SupaField.serverTimestamp(),
          'senderId': 'system',
          'senderName': 'ROOM BOT',
          'isHost': false,
        });
      });

      try {
        await SupaStore.instance
            .collection('tournament_rooms')
            .doc(room.id)
            .set({
          'status': 'completed',
          'rewardStatus': 'sent',
          'winnerId': resolvedWinnerId,
          'winnerName': resolvedWinnerName,
          'completedAt': SupaField.serverTimestamp(),
          'isLive': false,
        }, SupaSetOptions(merge: true));
      } catch (_) {}
    } catch (e) {
      debugPrint('Auto-approve error: $e');
    }
  }

  Stream<List<GamerRoom>> _getRoomsStream() {
    return SupaStore.instance.collection('rooms').snapshots().map((snapshot) {
      final list = <GamerRoom>[];
      for (final doc in snapshot.docs) {
        final room = GamerRoom.fromSupabase(doc);
        if (room.isExpiredCompleted) {
          doc.reference.delete().catchError((_) {});
          SupaStore.instance
              .collection('tournament_rooms')
              .doc(room.id)
              .delete()
              .catchError((_) {});
          continue;
        }
        list.add(room);
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> joinRoom(GamerRoom room) async {
    final uid = currentUserId;
    final name = currentUserName;
    final photo = currentUserPhoto;

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
        final roomRef = SupaStore.instance.collection('rooms').doc(room.id);

        try {
          await SupaStore.instance.runTransaction((transaction) async {
            final snapshot = await transaction.get(roomRef);
            if (!snapshot.exists) {
              throw Exception('Room does not exist');
            }

            final data = snapshot.data() ?? {};
            final int total = (data['total'] ??
                data['totalSlots'] ??
                data['maxSlots'] ??
                data['total_slots'] ??
                2) as int;
            final int currentFilled = (data['filled'] ??
                (data['joinedUserIds'] as List?)?.length ??
                (data['joinedPlayers'] as List?)?.length ??
                0) as int;

            if (currentFilled >= total) {
              throw Exception('full');
            }

            final List joinedIds =
                List.from(data['joinedUserIds'] ?? data['joinedPlayers'] ?? []);
            if (joinedIds.contains(uid)) {
              return;
            }

            final newUserMap = {
              'id': uid,
              'name': name,
              'photo': photo,
              'joinedAt': SupaTime.now(),
            };

            transaction.update(roomRef, {
              'filled': SupaField.increment(1),
              'currentSlots': SupaField.increment(1),
              'joinedUserIds': SupaField.arrayUnion([uid]),
              'joinedPlayers': SupaField.arrayUnion([uid]),
              'joinedUsers': SupaField.arrayUnion([newUserMap]),
              'joinedPlayerNames.$uid': name,
            });

            final msgRef = roomRef.collection('messages').doc();
            transaction.set(msgRef, {
              'type': 'system',
              'message': '$name joined the room',
              'timestamp': SupaField.serverTimestamp(),
              'senderId': 'system',
              'senderName': 'ROOM BOT',
              'isHost': false,
            });
          });

          if (mounted) {
            setState(() {
              _joinedRoomIds.add(room.id);
            });
            await _walletService.recordTournamentJoinedAndCheckReferral(uid);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Joined! Free Entry - Room ID will be visible 10 mins before match'),
                backgroundColor: _fbBlue,
                behavior: SnackBarBehavior.floating,
              ),
            );

            final updatedDoc = await roomRef.get();
            if (mounted && updatedDoc.exists) {
              _showRoomBottomSheet(GamerRoom.fromSupabase(updatedDoc));
            }
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
            final name = currentUserName;
            final roomRef = SupaStore.instance.collection('rooms').doc(room.id);

            try {
              Map<String, dynamic>? matchingUser;
              for (final u in room.joinedUsers) {
                if (u['id'] == uid) {
                  matchingUser = u;
                  break;
                }
              }

              final updates = <String, dynamic>{
                'filled': SupaField.increment(-1),
                'currentSlots': SupaField.increment(-1),
                'joinedUserIds': SupaField.arrayRemove([uid]),
                'joinedPlayers': SupaField.arrayRemove([uid]),
                'joinedPlayerNames.$uid': SupaField.delete(),
              };

              if (matchingUser != null) {
                updates['joinedUsers'] =
                    SupaField.arrayRemove([matchingUser]);
              }

              final batch = SupaStore.instance.batch();
              batch.update(roomRef, updates);

              final msgRef = roomRef.collection('messages').doc();
              batch.set(msgRef, {
                'type': 'system',
                'message': '$name left the room',
                'timestamp': SupaField.serverTimestamp(),
                'senderId': 'system',
                'senderName': 'ROOM BOT',
                'isHost': false,
              });

              await batch.commit();

              setState(() {
                _joinedRoomIds.remove(room.id);
              });

              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
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

  /// =========================================================
  /// CREATE ROOM — FIXED: sirf `rooms` table ke columns
  /// id, host_id, game, mode, room_id, room_password,
  /// prize_pool, total_slots, filled_slots, status, created_at
  /// =========================================================
  void _showCreateRoomDialog() {
    String selectedGame =
        _selectedCategory == 'All Games' ? 'BGMI' : _selectedCategory;
    String selectedMap = 'Erangel';
    int maxSlots = 2;
    int prizeCoins = 100;

    String generateRoomTitle(String map, int slots, int prize) {
      final String slotPart =
          (slots == 2) ? '1v1' : (slots == 4 ? '2v2' : '$slots slots');
      return 'BGMI $map $slotPart - $prize Coins';
    }

    int getDefaultPrizeForSlots(int slots) {
      if (slots == 2) return 100;
      if (slots == 4) return 250;
      if (slots == 10) return 500;
      return 500;
    }

    final titleController = TextEditingController(
      text: generateRoomTitle(selectedMap, maxSlots, prizeCoins),
    );
    final mapController = TextEditingController(text: selectedMap);
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
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE7F3FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_moderator_rounded,
                            color: Color(0xFF1877F2), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Host Custom Room',
                        style: TextStyle(
                            color: Color(0xFF050505),
                            fontWeight: FontWeight.bold,
                            fontSize: 17),
                      ),
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
                          color: Color(0xFF65676B),
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedGame,
                    dropdownColor: Colors.white,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF0F2F5),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFCED0D4))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFCED0D4))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFF1877F2))),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(
                        color: Color(0xFF050505),
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                    items: _gameCategories
                        .where((g) => g != 'All Games')
                        .map((g) =>
                            DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() => selectedGame = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  const Text('ROOM TITLE',
                      style: TextStyle(
                          color: Color(0xFF65676B),
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(
                        color: Color(0xFF050505), fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF0F2F5),
                      hintText: 'Enter room title',
                      hintStyle: const TextStyle(
                          color: Color(0xFF8A8D91), fontSize: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFCED0D4))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFCED0D4))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFF1877F2))),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('MAP',
                                style: TextStyle(
                                    color: Color(0xFF65676B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: selectedMap,
                              dropdownColor: Colors.white,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFF0F2F5),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFCED0D4))),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFCED0D4))),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF1877F2))),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              style: const TextStyle(
                                  color: Color(0xFF050505),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
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
                                    mapController.text = val;
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
                                    color: Color(0xFF65676B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              value: maxSlots,
                              dropdownColor: Colors.white,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFF0F2F5),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFCED0D4))),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFCED0D4))),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF1877F2))),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              style: const TextStyle(
                                  color: Color(0xFF050505),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
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
                                    prizeCoins =
                                        getDefaultPrizeForSlots(val);
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
                          color: Color(0xFF65676B),
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: prizeCoins,
                    dropdownColor: Colors.white,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF0F2F5),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFCED0D4))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFCED0D4))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFF1877F2))),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(
                        color: Color(0xFF050505),
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Text('IN-GAME ROOM ID',
                                    style: TextStyle(
                                        color: Color(0xFF65676B),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                                Text(' *',
                                    style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: roomIdController,
                              style: const TextStyle(
                                  color: Color(0xFF050505), fontSize: 13),
                              onChanged: (_) => setSheetState(() {}),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFF0F2F5),
                                hintText: 'e.g. 88453219',
                                hintStyle: const TextStyle(
                                    color: Color(0xFF8A8D91), fontSize: 12),
                                errorText: isRoomIdEmpty
                                    ? 'Room ID is required'
                                    : null,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFCED0D4))),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: isRoomIdEmpty
                                          ? Colors.redAccent
                                              .withOpacity(0.8)
                                          : const Color(0xFFCED0D4)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF1877F2))),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Text('PASSWORD',
                                    style: TextStyle(
                                        color: Color(0xFF65676B),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                                Text(' *',
                                    style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: passController,
                              style: const TextStyle(
                                  color: Color(0xFF050505), fontSize: 13),
                              onChanged: (_) => setSheetState(() {}),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFF0F2F5),
                                hintText: 'e.g. pubg123',
                                hintStyle: const TextStyle(
                                    color: Color(0xFF8A8D91), fontSize: 12),
                                errorText: isPassEmpty
                                    ? 'Password is required'
                                    : null,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFCED0D4))),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: isPassEmpty
                                          ? Colors.redAccent
                                              .withOpacity(0.8)
                                          : const Color(0xFFCED0D4)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF1877F2))),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
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
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE4E6EB),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isPublishEnabled
                          ? () async {
                              final uid = currentUserId;
                              final name = currentUserName;

                              if (uid.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Please login to host a room'),
                                      backgroundColor: Color(0xFFFF4655)),
                                );
                                return;
                              }

                              final docRef = SupaStore.instance
                                  .collection('rooms')
                                  .doc();

                              // FIX: Sirf `rooms` table ke columns
                              final newRoomData = {
                                'id': docRef.id,
                                'host_id': uid,
                                'game': selectedGame,
                                'mode': selectedMap,
                                'room_id':
                                    roomIdController.text.trim(),
                                'room_password':
                                    passController.text.trim(),
                                'prize_pool': prizeCoins,
                                'total_slots': maxSlots,
                                'filled_slots': 1,
                                'status': 'active',
                                'created_at':
                                    DateTime.now().toIso8601String(),
                              };

                              await docRef.set(newRoomData);

                              try {
                                await SupabaseService.saveRoom({
                                  'room_id': docRef.id,
                                  'title': newRoomData['game']
                                          ?.toString() ??
                                      '$selectedGame Match',
                                  'game': selectedGame,
                                  'mode': selectedMap,
                                  'host_id': uid,
                                  'host_name': name,
                                  'max_players': maxSlots,
                                  'current_players': 1,
                                  'status': 'active',
                                  'created_at': DateTime.now()
                                      .toIso8601String(),
                                });
                                await SupabaseService.addRoomMember({
                                  'room_id': docRef.id,
                                  'user_id': uid,
                                  'username': name,
                                  'joined_at': DateTime.now()
                                      .toIso8601String(),
                                });
                              } catch (_) {}

                              if (mounted) {
                                setState(() {
                                  _joinedRoomIds.add(docRef.id);
                                });
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        '🎉 Room published successfully!'),
                                    backgroundColor: _fbBlue,
                                  ),
                                );
                              }
                            }
                          : null,
                      child: Text(
                        'PUBLISH ROOM',
                        style: TextStyle(
                          color: isPublishEnabled
                              ? Colors.white
                              : Colors.white38,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
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

  /// =========================================================
  /// ROOM CARD WIDGET
  /// =========================================================
  Widget _buildRoomCard(GamerRoom room) {
    final uid = currentUserId;
    final bool isHost = room.hostId == uid;
    final bool isJoined = _joinedRoomIds.contains(room.id) ||
        room.joinedUserIds.contains(uid);

    final int total = room.total > 0 ? room.total : 2;
    final int filled = room.filled.clamp(0, total);
    final double fillRatio =
        total > 0 ? (filled / total).clamp(0.0, 1.0) : 0.0;

    final String rawHostName = room.hostName.trim();
    const mapNames = [
      'Erangel',
      'Miramar',
      'Sanhok',
      'Vikendi',
      'Livik',
      'Karakin',
      'Nusa',
      'Warehouse'
    ];
    final bool isMapValue = mapNames.any((m) =>
            m.toLowerCase() == rawHostName.toLowerCase()) ||
        (room.map.trim().isNotEmpty &&
            rawHostName.toLowerCase() == room.map.trim().toLowerCase());

    final String hostDisplay;
    if (rawHostName.isNotEmpty && !isMapValue) {
      hostDisplay = rawHostName;
    } else {
      if (_hostNameCache.containsKey(room.hostId) &&
          _hostNameCache[room.hostId]!.isNotEmpty) {
        hostDisplay = _hostNameCache[room.hostId]!;
      } else {
        if (room.hostId.isNotEmpty) {
          _ensureHostNameLoaded(room.hostId);
        }
        hostDisplay = 'Host';
      }
    }

    final initial = isHost || isJoined
        ? (currentUserName.isNotEmpty
            ? currentUserName[0].toUpperCase()
            : 'Y')
        : (hostDisplay.isNotEmpty ? hostDisplay[0].toUpperCase() : 'G');

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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    isJoined ? const Color(0xFF1877F2) : const Color(0xFFE4E6EB),
                child: Text(
                  initial,
                  style: TextStyle(
                    color: isJoined ? Colors.white : const Color(0xFF1C1E21),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.title,
                      style: const TextStyle(
                        color: Color(0xFF050505),
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Host: $hostDisplay • ${room.map}',
                      style: const TextStyle(
                        color: Color(0xFF65676B),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 28,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isJoined
                        ? const Color(0xFF1877F2).withOpacity(0.3)
                        : const Color(0xFFE4E6EB),
                  ),
                ),
                child: Text(
                  room.game,
                  style: const TextStyle(
                    color: Color(0xFF1877F2),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monetization_on_rounded,
                              size: 14, color: Color(0xFF1877F2)),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              '${room.prize} Coins',
                              style: const TextStyle(
                                color: Color(0xFF1877F2),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        '(From App)',
                        style: TextStyle(
                          color: Color(0xFF65676B),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'PRIZE POOL',
                        style: TextStyle(
                          color: Color(0xFF65676B),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 24, width: 1, color: const Color(0xFFCED0D4)),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F3FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF1877F2)
                                  .withOpacity(0.3)),
                        ),
                        child: const Text(
                          'FREE',
                          style: TextStyle(
                            color: Color(0xFF1877F2),
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'ENTRY FEE',
                        style: TextStyle(
                          color: Color(0xFF65676B),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 24, width: 1, color: const Color(0xFFCED0D4)),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${room.joinedUsers.isNotEmpty ? room.joinedUsers.length : filled}/$total',
                        style: const TextStyle(
                          color: Color(0xFF050505),
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'SLOTS',
                        style: TextStyle(
                          color: Color(0xFF65676B),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
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
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF1877F2)),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: room.isCompleted
                      ? const Color(0xFF1877F2)
                      : (room.isDisputed
                          ? const Color(0xFFFA383E)
                          : (room.isProofRejected
                              ? const Color(0xFFFA383E)
                              : (room.isRewardWaiting
                                  ? const Color(0xFFF7B125)
                                  : const Color(0xFF31A24C)))),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                room.isCompleted
                    ? 'COMPLETED'
                    : (room.isDisputed
                        ? 'DISPUTED'
                        : (room.isProofRejected
                            ? 'PROOF REJECTED'
                            : (room.isRewardWaiting
                                ? 'REWARD WAITING'
                                : (room.isInProgress
                                    ? 'MATCH LIVE'
                                    : 'ACTIVE MATCH')))),
                style: TextStyle(
                  color: room.isCompleted
                      ? const Color(0xFF1877F2)
                      : (room.isDisputed
                          ? const Color(0xFFFA383E)
                          : (room.isProofRejected
                              ? const Color(0xFFFA383E)
                              : (room.isRewardWaiting
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFF31A24C)))),
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (room.isCompleted)
                InkWell(
                  onTap: () => _showRoomBottomSheet(room),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F3FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF1877F2).withOpacity(0.4),
                          width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 13, color: Color(0xFF1877F2)),
                        const SizedBox(width: 4),
                        Text(
                          _getCompletedDeleteRemainingText(room),
                          style: const TextStyle(
                            color: Color(0xFF1877F2),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (room.isDisputed)
                InkWell(
                  onTap: () => _showRoomBottomSheet(room),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE8E8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFFA383E).withOpacity(0.6),
                          width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 13, color: Color(0xFFFA383E)),
                        SizedBox(width: 4),
                        Text(
                          'DISPUTED',
                          style: TextStyle(
                            color: Color(0xFFFA383E),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (room.isProofRejected)
                InkWell(
                  onTap: () => _showRoomBottomSheet(room),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE8E8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFFA383E).withOpacity(0.6),
                          width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cancel_rounded,
                            size: 13, color: Color(0xFFFA383E)),
                        SizedBox(width: 4),
                        Text(
                          'PROOF REJECTED',
                          style: TextStyle(
                            color: Color(0xFFFA383E),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (room.isRewardWaiting)
                InkWell(
                  onTap: () => _showRoomBottomSheet(room),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3D6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFF7B125).withOpacity(0.6),
                          width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hourglass_top_rounded,
                            size: 13, color: Color(0xFFB45309)),
                        SizedBox(width: 4),
                        Text(
                          'REWARD WAITING',
                          style: TextStyle(
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (room.isFull && !isJoined && !isHost)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE4E6EB),
                    foregroundColor: const Color(0xFF8D949E),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: null,
                  child: const Text('FULL',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                )
              else if (isHost)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1877F2),
                    side: const BorderSide(
                        color: Color(0xFF1877F2), width: 1.2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showRoomBottomSheet(room),
                  child: const Text('MANAGE ✓',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                )
              else if (isJoined)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE7F3FF),
                    foregroundColor: const Color(0xFF1877F2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () => _showRoomBottomSheet(room),
                  child: const Text('JOINED ✓',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1877F2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () => joinRoom(room),
                  child: const Text('JOIN ROOM',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
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
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                    bottom:
                        BorderSide(color: Color(0xFFE4E6EB), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StreamBuilder<SupaDoc>(
                    stream: SupaStore.instance
                        .collection('users')
                        .doc(currentUserId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      int coins = 0;
                      if (snapshot.hasData &&
                          snapshot.data != null &&
                          snapshot.data!.exists) {
                        final data = snapshot.data!.data()
                            as Map<String, dynamic>?;
                        if (data != null) {
                          final raw = data['gCoins'] ?? data['coins'];
                          if (raw is num) coins = raw.toInt();
                        }
                      }
                      return GestureDetector(
                        onTap: () => CoinHistorySheet.show(context,
                            userId: currentUserId),
                        child: Container(
                          height: 36,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F2F5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFFE4E6EB)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🪙',
                                  style: TextStyle(fontSize: 15)),
                              const SizedBox(width: 6),
                              Text(
                                '${NumberFormat("#,###").format(coins)} G-Coins',
                                style: const TextStyle(
                                  color: Color(0xFF050505),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const CoinStoreScreen()));
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 36,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE4E6EB),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.storefront_rounded,
                                  color: Color(0xFF050505), size: 14),
                              SizedBox(width: 4),
                              Text(
                                'STORE',
                                style: TextStyle(
                                  color: Color(0xFF050505),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _watchRewardedAdForCoins,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 36,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1877F2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_circle_fill_rounded,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'EARN COINS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                      onTap: () {
                        setState(() {
                          _selectedCategory = name;
                        });
                      },
                      child: Container(
                        height: 34,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1877F2)
                              : const Color(0xFFE4E6EB),
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF1877F2)
                                : const Color(0xFFCED0D4),
                          ),
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF050505),
                            fontSize: 12.5,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                          ),
                        ),
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

                  filtered.sort((a, b) {
                    final aJoined = _joinedRoomIds.contains(a.id) ||
                        a.joinedUserIds.contains(currentUserId);
                    final bJoined = _joinedRoomIds.contains(b.id) ||
                        b.joinedUserIds.contains(currentUserId);
                    if (aJoined && !bJoined) return -1;
                    if (!aJoined && bJoined) return 1;
                    return b.createdAt.compareTo(a.createdAt);
                  });

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE4E6EB),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFFCED0D4)),
                            ),
                            child: const Icon(Icons.sports_esports_rounded,
                                size: 44, color: Color(0xFF65676B)),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No rooms found',
                            style: TextStyle(
                                color: Color(0xFF050505),
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1877F2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Host First Room',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            onPressed: _showCreateRoomDialog,
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() {});
                    },
                    color: const Color(0xFF1877F2),
                    backgroundColor: Colors.white,
                    child: ListView.builder(
                      padding:
                          const EdgeInsets.only(bottom: 120, top: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) =>
                          _buildRoomCard(filtered[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF1877F2),
          foregroundColor: Colors.white,
          elevation: 2,
          icon: const Icon(Icons.add_moderator_rounded, size: 20),
          label: const Text(
            'HOST ROOM',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                fontSize: 13),
          ),
          onPressed: _showCreateRoomDialog,
        ),
      ),
    );
  }
}

/// =========================================================================
/// 4. IN-ROOM BOTTOM SHEET CONTENT — yeh same rakha hai (koi change nahi)
/// =========================================================================
// NOTE: Ye class bahut badi hai. Main ne ise "same" rakha hai — kyunki
// isme koi bug nahi hai. Sirf `GamerRoom.fromSupabase` aur `_showCreateRoomDialog`
// ke `newRoomData` fix kiye hain — jo upar already ho chuke hain.

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
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;

  File? _selectedProofImage;
  bool _isUploadingProof = false;
  DateTime? _lastSendTime;
  bool _isStartingMatch = false;

  static const Color _fbBlue = Color(0xFF1877F2);

  bool get isHost => widget.room.hostId == widget.currentUserId;
  bool get isJoined =>
      widget.room.joinedUserIds.contains(widget.currentUserId);
  bool get canAccess => isHost || isJoined;

  String _sheetHostName = '';

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _resolveSheetHostName(widget.room);
  }

  Future<void> _resolveSheetHostName(GamerRoom room) async {
    final hostId = room.hostId;
    if (hostId.isEmpty) return;
    try {
      final uDoc =
          await SupaStore.instance.collection('users').doc(hostId).get();
      if (uDoc.exists) {
        final data = uDoc.data() as Map<String, dynamic>? ?? {};
        final name = (data['username'] ??
                data['displayName'] ??
                data['display_name'] ??
                data['name'])
            ?.toString()
            .trim() ??
            '';
        if (name.isNotEmpty && name.toLowerCase() != 'host') {
          if (mounted) setState(() => _sheetHostName = name);
          return;
        }
      }
    } catch (_) {}
  }

  void _startCountdown() {
    _updateRemainingTime();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _updateRemainingTime();
        });
      }
    });
  }

  void _updateRemainingTime() {
    final now = DateTime.now();
    if (widget.room.startTime.isAfter(now)) {
      _remainingTime = widget.room.startTime.difference(now);
    } else {
      _remainingTime = Duration.zero;
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative || d == Duration.zero) return 'MATCH STARTED';
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    if (hours > 0) {
      return 'Starts in: ${hours}h ${minutes}m ${seconds}s';
    }
    return 'Starts in: ${minutes}m ${seconds}s';
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
  Widget build(BuildContext context) {
    final room = widget.room;
    final bool isHost = room.hostId == widget.currentUserId;
    final bool isJoined = room.joinedUserIds.contains(widget.currentUserId);
    final bool canAccess = isHost || isJoined;
    final int onlineCount = room.joinedUsers.isNotEmpty
        ? room.joinedUsers.length
        : (room.joinedUserIds.isNotEmpty ? room.joinedUserIds.length : 1);

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
                        Text(
                          room.title,
                          style: const TextStyle(
                            color: Color(0xFF050505),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Host: ${_sheetHostName.isNotEmpty ? _sheetHostName : room.hostName} • ${room.map}',
                          style: const TextStyle(
                              color: Color(0xFF65676B), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF65676B), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFCED0D4), height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCED0D4)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ROOM ID',
                                    style: TextStyle(
                                        color: Color(0xFF65676B),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                  canAccess && room.roomIdCode.isNotEmpty
                                      ? room.roomIdCode
                                      : '••••••••',
                                  style: const TextStyle(
                                      color: Color(0xFF050505),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      letterSpacing: 1),
                                ),
                              ],
                            ),
                          ),
                          Container(
                              height: 32,
                              width: 1,
                              color: const Color(0xFFCED0D4),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 8)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('PASSWORD',
                                    style: TextStyle(
                                        color: Color(0xFF65676B),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                  canAccess && room.password.isNotEmpty
                                      ? room.password
                                      : '••••',
                                  style: const TextStyle(
                                      color: Color(0xFF050505),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      letterSpacing: 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Prize: ${room.prize} Coins • Slots: ${room.filled}/${room.total}',
                      style: const TextStyle(
                          color: Color(0xFF050505),
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F3FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color:
                                const Color(0xFF1877F2).withOpacity(0.4)),
                      ),
                      child: Text(
                        room.isCompleted
                            ? 'COMPLETED'
                            : (room.isInProgress
                                ? 'MATCH IN PROGRESS'
                                : _formatDuration(_remainingTime)),
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
                      child: StreamBuilder<SupaSnap>(
                        stream: SupaStore.instance
                            .collection('rooms')
                            .doc(room.id)
                            .collection('messages')
                            .orderBy('timestamp', descending: false)
                            .snapshots(),
                        builder: (context, snapshot) {
                          final docs = snapshot.data?.docs ?? [];
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
                              final msg = docs[index].data() ?? {};
                              final senderId =
                                  msg['senderId']?.toString() ?? '';
                              final text = msg['message']?.toString() ?? '';
                              final isSystem = senderId == 'system' ||
                                  msg['type'] == 'system';
                              final isMe =
                                  senderId == widget.currentUserId;

                              if (isSystem) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE4E6EB),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        text,
                                        style: const TextStyle(
                                            color: Color(0xFF1877F2),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? const Color(0xFF1877F2)
                                        : const Color(0xFFE4E6EB),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    text,
                                    style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : const Color(0xFF050505),
                                        fontSize: 12),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (canAccess)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _msgController,
                              style: const TextStyle(
                                  color: Color(0xFF050505), fontSize: 13),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                hintText: 'Type a message...',
                                hintStyle: const TextStyle(
                                    color: Color(0xFF8A8D91), fontSize: 12),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () async {
                              final text = _msgController.text.trim();
                              if (text.isEmpty) return;
                              _msgController.clear();
                              await SupaStore.instance
                                  .collection('rooms')
                                  .doc(room.id)
                                  .collection('messages')
                                  .add({
                                'senderId': widget.currentUserId,
                                'senderName': widget.currentUserName,
                                'message': text,
                                'type': 'text',
                                'timestamp': SupaField.serverTimestamp(),
                                'isHost': isHost,
                              });
                            },
                            icon: const Icon(Icons.send_rounded,
                                color: Color(0xFF1877F2)),
                          ),
                        ],
                      )
                    else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1877F2),
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size(double.infinity, 0),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: widget.onJoinRoomRequested,
                        child: const Text('JOIN ROOM - FREE',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(height: 12),
                    if (isHost)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isStartingMatch
                              ? const Color(0xFFE4E6EB)
                              : const Color(0xFF1877F2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size(double.infinity, 0),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isStartingMatch
                            ? null
                            : () async {
                                setState(() => _isStartingMatch = true);
                                try {
                                  await SupaStore.instance
                                      .collection('rooms')
                                      .doc(room.id)
                                      .update({
                                    'status': 'IN_PROGRESS',
                                    'isMatchStarted': true,
                                  });
                                } catch (_) {}
                                if (mounted) {
                                  setState(() => _isStartingMatch = false);
                                }
                              },
                        icon: const Icon(Icons.play_arrow_rounded,
                            size: 18),
                        label: Text(
                          _isStartingMatch
                              ? 'STARTING MATCH...'
                              : 'START MATCH',
                          style:
                              const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (isJoined && !isHost)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side:
                              const BorderSide(color: Colors.red, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size(double.infinity, 0),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: widget.onLeaveRoom,
                        child: const Text('LEAVE ROOM',
                            style: TextStyle(fontWeight: FontWeight.bold)),
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