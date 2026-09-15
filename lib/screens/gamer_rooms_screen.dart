import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import '../services/cloudinary_service.dart';
import 'coin_store_screen.dart';
import 'redeem_rewards_screen.dart';
import '../widgets/coin_history_sheet.dart';

// Backwards compatibility across older navigators
// TournamentBoardScreen is defined in tournament_board_screen.dart

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
  final String rewardStatus; // 'idle', 'sending', 'sent', 'pending_host', 'rejected_by_app'
  final String? winnerId;
  final String? winnerName;
  final String prizeSource; // 'application'
  final String ocrStatus; // 'verified', 'doubt', 'none'
  final String ocrText;
  final int ocrScore;
  final String? proofUrl;

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
  });

  bool get isFull => filled >= total;
  bool get isCompleted => status.toLowerCase() == 'completed' || rewardStatus == 'sent';
  bool get isActive => !isCompleted && (status.toLowerCase() == 'active' || status.toUpperCase() == 'OPEN');

  factory GamerRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final id = doc.id;
    final title = (data['title'] ?? 'Custom Match').toString();
    final hostId = (data['hostId'] ?? '').toString();
    final hostName = (data['hostName'] ?? 'Host').toString();
    final map = (data['map'] ?? 'Erangel').toString();
    final game = (data['game'] ?? data['gameType'] ?? data['gameName'] ?? 'BGMI').toString();

    int prize = 500;
    if (data['prize'] is num) {
      prize = (data['prize'] as num).toInt();
    } else if (data['prizePoolCoins'] is num) {
      prize = (data['prizePoolCoins'] as num).toInt();
    }

    // Free entry for all rooms
    const entryFee = 'FREE';

    final int total = (data['total'] ?? data['totalSlots'] ?? data['maxSlots'] ?? 2) as int;

    final List<String> joinedUserIds = List<String>.from(data['joinedUserIds'] ?? data['joinedPlayers'] ?? []);

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
          'joinedAt': data['createdAt'] ?? Timestamp.now(),
        });
      }
    }

    final int filled = (data['filled'] ??
        (joinedUsers.isNotEmpty
            ? joinedUsers.length
            : (joinedUserIds.isNotEmpty ? joinedUserIds.length : (data['currentSlots'] ?? 1)))) as int;

    final roomIdCode = (data['roomIdCode'] ?? data['roomId'] ?? '').toString();
    final password = (data['password'] ?? '').toString();
    final status = (data['status'] ?? 'active').toString();
    final rewardStatus = (data['rewardStatus'] ?? (status.toLowerCase() == 'completed' ? 'sent' : 'idle')).toString();
    final winnerId = data['winnerId']?.toString();
    final winnerName = data['winnerName']?.toString();
    final prizeSource = (data['prizeSource'] ?? 'application').toString();
    final ocrStatus = (data['ocrStatus'] ?? 'none').toString();
    final ocrText = (data['ocrText'] ?? '').toString();
    final int ocrScore = (data['ocrScore'] is num) ? (data['ocrScore'] as num).toInt() : 0;
    final proofUrl = data['proofUrl']?.toString() ?? data['winProofUrl']?.toString();

    DateTime created = DateTime.now();
    if (data['createdAt'] is Timestamp) {
      created = (data['createdAt'] as Timestamp).toDate();
    }

    DateTime start = DateTime.now().add(const Duration(minutes: 15));
    if (data['startTime'] is Timestamp) {
      start = (data['startTime'] as Timestamp).toDate();
    } else if (data['startTime'] is String) {
      start = DateTime.tryParse(data['startTime']) ?? start;
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

  // Cache for host usernames fetched from Firestore 'users' collection to avoid repeated reads
  final Map<String, String> _hostNameCache = {};

  /// Ensure host display name is loaded into cache (reads users collection once per hostId)
  Future<void> _ensureHostNameLoaded(String hostId) async {
    if (hostId.isEmpty || _hostNameCache.containsKey(hostId)) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(hostId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final username = (data['username'] ?? data['displayName'] ?? data['name'])?.toString().trim() ?? '';
        if (username.isNotEmpty) {
          _hostNameCache[hostId] = username;
          if (mounted) setState(() {});
          return;
        }
      }
    } catch (_) {}
    _hostNameCache[hostId] = 'Host';
  }

  static const Color _neonGreen = Color(0xFF00FF88);

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
      FirebaseAuth.instance.currentUser?.uid ??
      _authService.currentGamer?.uid ??
      _authService.currentUid ??
      'guest';

  String get currentUserName =>
      FirebaseAuth.instance.currentUser?.displayName ??
      _authService.currentGamer?.displayName ??
      'Gamer';

  String get currentUserPhoto =>
      FirebaseAuth.instance.currentUser?.photoURL ??
      _authService.currentGamer?.photoUrl ??
      '';

  @override
  void initState() {
    super.initState();
    _walletService.getOrCreateWallet(currentUserId);
    _walletService.addListener(_onWalletChanged);
  }

  void _onWalletChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _walletService.removeListener(_onWalletChanged);
    super.dispose();
  }

  /// Real-time stream for rooms from Firestore
  Stream<List<GamerRoom>> _getRoomsStream() {
    return FirebaseFirestore.instance
        .collection('rooms')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => GamerRoom.fromFirestore(doc)).toList();
      // Sort newest first
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// =========================================================================
  /// 3. JOIN LOGIC - FIX OVER-JOIN BUG (Firestore Transaction)
  /// =========================================================================
  Future<void> joinRoom(GamerRoom room) async {
    final uid = currentUserId;
    final name = currentUserName;
    final photo = currentUserPhoto;

    final isAlreadyJoined = _joinedRoomIds.contains(room.id) || room.joinedUserIds.contains(uid);
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

    // All rooms have 100% FREE entry - No coin deduction, no escrow hold
    await AdFreeService().showRewardedAdForAction(
      context: context,
      actionTitle: 'Watch 1 Ad to Join Room',
      onRewardEarned: () async {
        final roomRef = FirebaseFirestore.instance.collection('rooms').doc(room.id);

        try {
          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final snapshot = await transaction.get(roomRef);
            if (!snapshot.exists) {
              throw Exception('Room does not exist');
            }

            final data = snapshot.data() ?? {};
            final int total = (data['total'] ?? data['totalSlots'] ?? data['maxSlots'] ?? 2) as int;
            final int currentFilled = (data['filled'] ??
                (data['joinedUserIds'] as List?)?.length ??
                (data['joinedPlayers'] as List?)?.length ??
                0) as int;

            if (currentFilled >= total) {
              throw Exception('full');
            }

            final List joinedIds = List.from(data['joinedUserIds'] ?? data['joinedPlayers'] ?? []);
            if (joinedIds.contains(uid)) {
              return;
            }

            final newUserMap = {
              'id': uid,
              'name': name,
              'photo': photo,
              'joinedAt': Timestamp.now(),
            };

            // FREE ENTRY: Update filled and joined users, NO coin deduction
            transaction.update(roomRef, {
              'filled': FieldValue.increment(1),
              'currentSlots': FieldValue.increment(1),
              'joinedUserIds': FieldValue.arrayUnion([uid]),
              'joinedPlayers': FieldValue.arrayUnion([uid]),
              'joinedUsers': FieldValue.arrayUnion([newUserMap]),
              'joinedPlayerNames.$uid': name,
            });

            // System message: "$name joined the room"
            final msgRef = roomRef.collection('messages').doc();
            transaction.set(msgRef, {
              'type': 'system',
              'message': '$name joined the room',
              'timestamp': FieldValue.serverTimestamp(),
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
                content: Text('Joined! Free Entry - Room ID will be visible 10 mins before match'),
                backgroundColor: _neonGreen,
                behavior: SnackBarBehavior.floating,
              ),
            );

            // Fetch fresh room copy and open sheet
            final updatedDoc = await roomRef.get();
            if (mounted && updatedDoc.exists) {
              _showRoomBottomSheet(GamerRoom.fromFirestore(updatedDoc));
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.toString().contains('full') ? 'Room is full' : 'Could not join room: $e'),
                backgroundColor: GamerTheme.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
    );
  }

  /// =========================================================================
  /// 4. BOTTOM SHEET
  /// =========================================================================
  void _showRoomBottomSheet(GamerRoom room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GamerTheme.cardDark,
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
            final roomRef = FirebaseFirestore.instance.collection('rooms').doc(room.id);

            try {
              // Find matching user map
              Map<String, dynamic>? matchingUser;
              for (final u in room.joinedUsers) {
                if (u['id'] == uid) {
                  matchingUser = u;
                  break;
                }
              }

              final updates = <String, dynamic>{
                'filled': FieldValue.increment(-1),
                'currentSlots': FieldValue.increment(-1),
                'joinedUserIds': FieldValue.arrayRemove([uid]),
                'joinedPlayers': FieldValue.arrayRemove([uid]),
                'joinedPlayerNames.$uid': FieldValue.delete(),
              };

              if (matchingUser != null) {
                updates['joinedUsers'] = FieldValue.arrayRemove([matchingUser]);
              }

              final batch = FirebaseFirestore.instance.batch();
              batch.update(roomRef, updates);

              // Add leave system message
              final msgRef = roomRef.collection('messages').doc();
              batch.set(msgRef, {
                'type': 'system',
                'message': '$name left the room',
                'timestamp': FieldValue.serverTimestamp(),
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

  /// Create / Host Room Dialog
  void _showCreateRoomDialog() {
    String selectedGame = _selectedCategory == 'All Games' ? 'BGMI' : _selectedCategory;
    String selectedMap = 'Erangel';
    int maxSlots = 2;
    int prizeCoins = 100; // default for 2 slots

    String generateRoomTitle(String map, int slots, int prize) {
      final String slotPart = (slots == 2)
          ? '1v1'
          : (slots == 4 ? '2v2' : '$slots slots');
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
      backgroundColor: GamerTheme.cardDark,
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
                      const Icon(Icons.add_moderator_rounded, color: GamerTheme.accentOrange, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Host Custom Room',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: GamerTheme.textMuted),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Game Dropdown
                  const Text('SELECT GAME', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedGame,
                    dropdownColor: GamerTheme.cardElevated,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: GamerTheme.bgDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: _gameCategories
                        .where((g) => g != 'All Games')
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() => selectedGame = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Room Title (auto-generated, user can edit)
                  const Text('ROOM TITLE', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: GamerTheme.bgDark,
                      hintText: 'Enter room title',
                      hintStyle: const TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Map & Slots Dropdowns
                  Row(
                    children: [
                      // MAP Dropdown
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('MAP', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: selectedMap,
                              dropdownColor: GamerTheme.cardElevated,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: GamerTheme.bgDark,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: const [
                                DropdownMenuItem(value: 'Erangel', child: Text('Erangel')),
                                DropdownMenuItem(value: 'Miramar', child: Text('Miramar')),
                                DropdownMenuItem(value: 'Sanhok', child: Text('Sanhok')),
                                DropdownMenuItem(value: 'Vikendi', child: Text('Vikendi')),
                                DropdownMenuItem(value: 'Livik', child: Text('Livik')),
                                DropdownMenuItem(value: 'Karakin', child: Text('Karakin')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setSheetState(() {
                                    selectedMap = val;
                                    mapController.text = val;
                                    titleController.text = generateRoomTitle(selectedMap, maxSlots, prizeCoins);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // SLOTS Dropdown
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SLOTS', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              value: maxSlots,
                              dropdownColor: GamerTheme.cardElevated,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: GamerTheme.bgDark,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: const [
                                DropdownMenuItem(value: 2, child: Text('2 (1v1)')),
                                DropdownMenuItem(value: 4, child: Text('4 (2v2)')),
                                DropdownMenuItem(value: 10, child: Text('10 slots')),
                                DropdownMenuItem(value: 12, child: Text('12 slots')),
                                DropdownMenuItem(value: 24, child: Text('24 slots')),
                                DropdownMenuItem(value: 50, child: Text('50 slots')),
                                DropdownMenuItem(value: 100, child: Text('100 slots')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setSheetState(() {
                                    maxSlots = val;
                                    prizeCoins = getDefaultPrizeForSlots(val);
                                    titleController.text = generateRoomTitle(selectedMap, maxSlots, prizeCoins);
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

                  // PRIZE Dropdown
                  const Text('PRIZE POOL', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: prizeCoins,
                    dropdownColor: GamerTheme.cardElevated,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: GamerTheme.bgDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 100, child: Text('💰 100 Coins')),
                      DropdownMenuItem(value: 250, child: Text('💰 250 Coins')),
                      DropdownMenuItem(value: 500, child: Text('💰 500 Coins')),
                      DropdownMenuItem(value: 1000, child: Text('💰 1000 Coins')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() {
                          prizeCoins = val;
                          titleController.text = generateRoomTitle(selectedMap, maxSlots, prizeCoins);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // In-Game Room ID & Password (Required with red * and errorText)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ROOM ID
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Text(
                                  'IN-GAME ROOM ID',
                                  style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  ' *',
                                  style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: roomIdController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              onChanged: (_) => setSheetState(() {}),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: GamerTheme.bgDark,
                                hintText: 'e.g. 88453219',
                                hintStyle: const TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                                errorText: isRoomIdEmpty ? 'Room ID is required' : null,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: isRoomIdEmpty ? Colors.redAccent.withOpacity(0.8) : GamerTheme.borderDark),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // PASSWORD
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Text(
                                  'PASSWORD',
                                  style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  ' *',
                                  style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: passController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              onChanged: (_) => setSheetState(() {}),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: GamerTheme.bgDark,
                                hintText: 'e.g. pubg123',
                                hintStyle: const TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                                errorText: isPassEmpty ? 'Password is required' : null,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: isPassEmpty ? Colors.redAccent.withOpacity(0.8) : GamerTheme.borderDark),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // PUBLISH ROOM Button (disabled when Room ID or Password is empty)
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPublishEnabled ? GamerTheme.accentOrange : Colors.grey.shade800,
                        disabledBackgroundColor: Colors.grey.shade800,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isPublishEnabled
                          ? () async {
                              final uid = currentUserId;
                              final name = currentUserName;
                              final photo = currentUserPhoto;
                              final docRef = FirebaseFirestore.instance.collection('rooms').doc();

                              final newRoomData = {
                                'id': docRef.id,
                                'title': titleController.text.trim().isNotEmpty ? titleController.text.trim() : '$selectedGame Match',
                                'hostId': uid,
                                'hostName': name,
                                'hostAvatar': photo,
                                'game': selectedGame,
                                'gameType': selectedGame,
                                'map': selectedMap,
                                'prize': prizeCoins,
                                'prizePoolCoins': prizeCoins,
                                'entryFee': 'FREE',
                                'entryFeeCoins': 0,
                                'total': maxSlots,
                                'totalSlots': maxSlots,
                                'maxSlots': maxSlots,
                                'filled': 1,
                                'currentSlots': 1,
                                'joinedUserIds': [uid],
                                'joinedPlayers': [uid],
                                'joinedUsers': [
                                  {
                                    'id': uid,
                                    'name': name,
                                    'photo': photo,
                                    'joinedAt': Timestamp.now(),
                                  }
                                ],
                                'joinedPlayerNames': {uid: name},
                                'roomIdCode': roomIdController.text.trim(),
                                'roomId': roomIdController.text.trim(),
                                'password': passController.text.trim(),
                                'status': 'active',
                                'createdAt': FieldValue.serverTimestamp(),
                                'startTime': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 15))),
                                'isLive': true,
                              };

                              await docRef.set(newRoomData);

                              if (mounted) {
                                setState(() {
                                  _joinedRoomIds.add(docRef.id);
                                });
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('🎉 Room published successfully!'),
                                    backgroundColor: _neonGreen,
                                  ),
                                );
                              }
                            }
                          : null,
                      child: Text(
                        'PUBLISH ROOM',
                        style: TextStyle(
                          color: isPublishEnabled ? Colors.white : Colors.white38,
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

  /// =========================================================================
  /// ROOM CARD WIDGET
  /// =========================================================================
  Widget _buildRoomCard(GamerRoom room) {
    final uid = currentUserId;
    final bool isHost = room.hostId == uid;
    final bool isJoined = _joinedRoomIds.contains(room.id) || room.joinedUserIds.contains(uid);

    final int total = room.total > 0 ? room.total : 2;
    final int filled = room.filled.clamp(0, total);
    final double fillRatio = total > 0 ? (filled / total).clamp(0.0, 1.0) : 0.0;

    // hostDisplay logic: if room.hostName is not null, not empty, and not equal to map values like
    // "Erangel", "Miramar", "Sanhok", "Vikendi" then use room.hostName.
    // Else, fetch username from Firestore collection 'users' docId = room.hostId.
    // Use field 'username' -> 'displayName' -> 'name' in that order.
    // Cache result in a Map<String, String> _hostNameCache to avoid repeated reads.
    final String rawHostName = room.hostName.trim();
    const mapNames = ['Erangel', 'Miramar', 'Sanhok', 'Vikendi', 'Livik', 'Karakin', 'Nusa', 'Warehouse'];
    final bool isMapValue = mapNames.any((m) => m.toLowerCase() == rawHostName.toLowerCase()) ||
        (room.map.trim().isNotEmpty && rawHostName.toLowerCase() == room.map.trim().toLowerCase());

    final String hostDisplay;
    if (rawHostName.isNotEmpty && !isMapValue) {
      hostDisplay = rawHostName;
    } else {
      if (_hostNameCache.containsKey(room.hostId) && _hostNameCache[room.hostId]!.isNotEmpty) {
        hostDisplay = _hostNameCache[room.hostId]!;
      } else {
        if (room.hostId.isNotEmpty) {
          _ensureHostNameLoaded(room.hostId);
        }
        hostDisplay = rawHostName.isNotEmpty && !isMapValue ? rawHostName : 'Host';
      }
    }

    final initial = isHost || isJoined
        ? (currentUserName.isNotEmpty ? currentUserName[0].toUpperCase() : 'Y')
        : (hostDisplay.isNotEmpty ? hostDisplay[0].toUpperCase() : 'G');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isJoined ? _neonGreen : GamerTheme.borderDark,
          width: isJoined ? 2.0 : 1.0,
        ),
        boxShadow: isJoined
            ? [
                BoxShadow(
                  color: _neonGreen.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar 40 + Title + Game Badge
          Row(
            children: [
              CircleAvatar(
                radius: 20, // 40px diameter
                backgroundColor: (isHost || isJoined) ? _neonGreen : GamerTheme.accentOrange,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: (isHost || isJoined) ? Colors.black : Colors.white,
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
                        color: GamerTheme.textWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Host: $hostDisplay • ${room.map}',
                      style: const TextStyle(
                        color: GamerTheme.textGray,
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
                width: 85,
                height: 28,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: GamerTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isJoined ? _neonGreen.withOpacity(0.5) : GamerTheme.borderDark,
                  ),
                ),
                child: Text(
                  room.game,
                  style: TextStyle(
                    color: isJoined ? _neonGreen : GamerTheme.textWhite,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Middle: Container bgDark 0.6 radius 12 padding 12 Row 3 cols
          Container(
            decoration: BoxDecoration(
              color: GamerTheme.bgDark.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // PRIZE POOL
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monetization_on_rounded, size: 14, color: Colors.cyanAccent),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              '${room.prize} Coins',
                              style: const TextStyle(
                                color: Colors.cyanAccent,
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
                      Text(
                        '(From App)',
                        style: TextStyle(
                          color: _neonGreen.withOpacity(0.9),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'PRIZE POOL',
                        style: TextStyle(
                          color: GamerTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 24, width: 1, color: GamerTheme.borderDark),

                // ENTRY FEE
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _neonGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _neonGreen.withOpacity(0.5)),
                        ),
                        child: const Text(
                          'FREE',
                          style: TextStyle(
                            color: _neonGreen,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
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
                          color: GamerTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 24, width: 1, color: GamerTheme.borderDark),

                // SLOTS
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${room.joinedUsers.isNotEmpty ? room.joinedUsers.length : filled}/$total',
                        style: TextStyle(
                          color: GamerTheme.textWhite,
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
                          color: GamerTheme.textMuted,
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

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fillRatio,
              minHeight: 4,
              backgroundColor: Colors.grey.withOpacity(0.25),
              valueColor: AlwaysStoppedAnimation<Color>(
                isHost
                    ? GamerTheme.accentOrange
                    : (isJoined
                        ? _neonGreen
                        : (fillRatio >= 0.7 ? const Color(0xFFFF3366) : const Color(0xFFFFD700))),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Bottom Row: ACTIVE MATCH dot + Spacer + Action Button
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: room.isCompleted ? Colors.amber : _neonGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                room.isCompleted ? 'COMPLETED' : 'ACTIVE MATCH',
                style: TextStyle(
                  color: room.isCompleted ? Colors.amber : _neonGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Button logic
              if (room.isFull && !isJoined && !isHost)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GamerTheme.cardElevated,
                    foregroundColor: GamerTheme.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: null,
                  child: const Text('FULL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                )
              else if (isHost)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GamerTheme.accentOrange,
                    side: const BorderSide(color: GamerTheme.accentOrange, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showRoomBottomSheet(room),
                  child: const Text('MANAGE ✓', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                )
              else if (isJoined)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () => _showRoomBottomSheet(room),
                  child: const Text('JOINED ✓', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GamerTheme.accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () => joinRoom(room),
                  child: const Text('JOIN ROOM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
      backgroundColor: GamerTheme.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: G-Coins + REDEEM + EARN COINS (height 36)
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: const BoxDecoration(
                color: GamerTheme.cardDark,
                border: Border(bottom: BorderSide(color: GamerTheme.borderDark)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // G-Coins button (Live Stream from users collection)
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUserId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      int coins = 0;
                      if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>?;
                        if (data != null) {
                          final raw = data['gCoins'] ?? data['coins'];
                          if (raw is num) coins = raw.toInt();
                        }
                      }
                      return GestureDetector(
                        onTap: () => CoinHistorySheet.show(context, userId: currentUserId),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: GamerTheme.bgDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: GamerTheme.borderDark),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🪙', style: TextStyle(fontSize: 15)),
                              const SizedBox(width: 6),
                              Text(
                                '${NumberFormat("#,###").format(coins)} G-Coins',
                                style: TextStyle(
                                  color: GamerTheme.textWhite,
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
                  // Action buttons: REDEEM outline orange + EARN COINS solid orange
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const RedeemRewardsScreen()));
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: GamerTheme.accentOrange, width: 1.2),
                              ),
                              child: const Text(
                                'REDEEM',
                                style: TextStyle(
                                  color: GamerTheme.accentOrange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const CoinStoreScreen()));
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: GamerTheme.accentOrange,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'EARN COINS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ),

            // Filter chips: All Games, BGMI, Free Fire, PUBG Mobile
            Container(
              color: GamerTheme.bgDark,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: 36,
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
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? GamerTheme.accentOrange : GamerTheme.cardDark,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected ? GamerTheme.accentOrange : GamerTheme.borderDark,
                          ),
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : GamerTheme.textGray,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Main Room List
            Expanded(
              child: StreamBuilder<List<GamerRoom>>(
                stream: _getRoomsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: GamerTheme.accentOrange));
                  }

                  final allRooms = snapshot.data ?? [];
                  final filtered = allRooms.where((r) {
                    if (_selectedCategory == 'All Games') return true;
                    return r.game.toLowerCase().trim() == _selectedCategory.toLowerCase().trim();
                  }).toList();

                  // Sort: User's joined/hosted rooms float to top
                  filtered.sort((a, b) {
                    final aJoined = _joinedRoomIds.contains(a.id) || a.joinedUserIds.contains(currentUserId);
                    final bJoined = _joinedRoomIds.contains(b.id) || b.joinedUserIds.contains(currentUserId);
                    if (aJoined && !bJoined) return -1;
                    if (!aJoined && bJoined) return 1;
                    return b.createdAt.compareTo(a.createdAt);
                  });

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sports_esports_rounded, size: 52, color: GamerTheme.textMuted.withOpacity(0.5)),
                          const SizedBox(height: 12),
                          const Text(
                            'No rooms found',
                            style: TextStyle(color: GamerTheme.textMuted, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GamerTheme.accentOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Host First Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                    color: GamerTheme.accentOrange,
                    backgroundColor: GamerTheme.cardDark,
                    child: ListView.builder(
                      // Padding bottom 120 avoids FAB and bottom nav overlap
                      padding: const EdgeInsets.only(bottom: 120, top: 4),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => _buildRoomCard(filtered[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // Positioned above bottom nav bar cleanly
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: FloatingActionButton.extended(
          backgroundColor: GamerTheme.accentOrange,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_moderator_rounded, size: 20),
          label: const Text(
            'HOST ROOM',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 13),
          ),
          onPressed: _showCreateRoomDialog,
        ),
      ),
    );
  }
}

/// =========================================================================
/// 4. IN-ROOM BOTTOM SHEET CONTENT
/// =========================================================================
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
  State<_InRoomBottomSheetContent> createState() => _InRoomBottomSheetContentState();
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

  static const Color _neonGreen = Color(0xFF00FF88);

  bool get isHost => widget.room.hostId == widget.currentUserId;
  bool get isJoined => widget.room.joinedUserIds.contains(widget.currentUserId);
  bool get canAccess => isHost || isJoined;

  @override
  void initState() {
    super.initState();
    _startCountdown();
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

  // Copy helper with feedback
  void _copyToClipboard(String label, String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: _neonGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Pick Image for Win Proof
  Future<void> _pickImage(ImageSource source) async {
    if (!canAccess) return;
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1080,
      );
      if (picked != null) {
        final file = File(picked.path);
        final sizeBytes = await file.length();
        if (sizeBytes > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image size must be less than 5MB'),
                backgroundColor: GamerTheme.redAccent,
              ),
            );
          }
          return;
        }
        setState(() {
          _selectedProofImage = file;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  /// ON SCREENSHOT UPLOAD - APP AUTO-READ OCR & VETO SYSTEM
  Future<Map<String, dynamic>> autoReadProof(File imageFile, String roomId, String downloadUrl) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(inputImage);
      final String text = result.text.toLowerCase();
      await recognizer.close();

      final bool hasWinnerKeyword = text.contains('winner winner') ||
          text.contains('chicken dinner') ||
          text.contains('rank #1') ||
          text.contains('rank 1') ||
          text.contains('team victory') ||
          text.contains('victory') ||
          (text.contains('winner') && text.contains('team'));

      // Confidence: kam se kam 2 cheezein honi chahiye
      int score = 0;
      if (text.contains('winner')) score++;
      if (text.contains('rank')) score++;
      if (text.contains('victory') || text.contains('chicken')) score++;
      if (text.length > 20) score++; // khali image nahi

      final String ocrStatus = (hasWinnerKeyword && score >= 2) ? 'verified' : 'doubt';
      final String trimmedText = text.length > 300 ? text.substring(0, 300) : text;

      // Firestore me save - Yahi veto hai
      await FirebaseFirestore.instance.collection('rooms').doc(roomId).update({
        'proofUrl': downloadUrl,
        'winProofUrl': downloadUrl,
        'ocrText': trimmedText,
        'ocrScore': score,
        'ocrStatus': ocrStatus, // verified ya doubt
        'rewardStatus': ocrStatus == 'verified' ? 'pending_host' : 'rejected_by_app',
      });

      return {
        'ocrStatus': ocrStatus,
        'ocrScore': score,
        'ocrText': trimmedText,
      };
    } catch (e) {
      try {
        await recognizer.close();
      } catch (_) {}
      debugPrint('OCR Error: $e');
      final errText = 'Error reading screenshot: $e';
      await FirebaseFirestore.instance.collection('rooms').doc(roomId).update({
        'proofUrl': downloadUrl,
        'winProofUrl': downloadUrl,
        'ocrText': errText,
        'ocrScore': 0,
        'ocrStatus': 'doubt',
        'rewardStatus': 'rejected_by_app',
      });
      return {
        'ocrStatus': 'doubt',
        'ocrScore': 0,
        'ocrText': errText,
      };
    }
  }

  // Send message or Win Proof
  Future<void> _sendMessage() async {
    if (!canAccess) return;

    // 1-second spam protection
    final now = DateTime.now();
    if (_lastSendTime != null && now.difference(_lastSendTime!) < const Duration(seconds: 1)) {
      return;
    }
    _lastSendTime = now;

    final text = _msgController.text.trim();
    if (text.isEmpty && _selectedProofImage == null) return;

    final messagesRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.room.id)
        .collection('messages');

    if (_selectedProofImage != null) {
      setState(() {
        _isUploadingProof = true;
      });

      try {
        // Upload to Cloudinary folder win_proofs
        String? uploadedUrl = await CloudinaryService.uploadFile(
          file: _selectedProofImage!,
          folder: 'win_proofs',
        );

        if (uploadedUrl == null || uploadedUrl.isEmpty) {
          throw Exception('Upload failed');
        }

        // Run OCR with App Veto evaluation
        final ocrRes = await autoReadProof(_selectedProofImage!, widget.room.id, uploadedUrl);
        final String ocrStatus = (ocrRes['ocrStatus'] ?? 'doubt').toString();
        final int ocrScore = (ocrRes['ocrScore'] is num) ? (ocrRes['ocrScore'] as num).toInt() : 0;
        final String ocrText = (ocrRes['ocrText'] ?? '').toString();

        await messagesRef.add({
          'senderId': widget.currentUserId,
          'senderName': widget.currentUserName,
          'senderInitial': widget.currentUserName.isNotEmpty ? widget.currentUserName[0].toUpperCase() : 'G',
          'message': text.isNotEmpty ? text : 'Submitted Match Win Proof',
          'imageUrl': uploadedUrl,
          'type': 'win_proof',
          'ocrStatus': ocrStatus,
          'ocrScore': ocrScore,
          'ocrText': ocrText,
          'timestamp': FieldValue.serverTimestamp(),
          'isHost': isHost,
        });

        // App AI Bot Announcement
        final systemMsg = ocrStatus == 'verified'
            ? '🤖 App AI Check: ✅ Verified Winner Screenshot (Score $ocrScore/4). Awaiting Host Approval.'
            : '🤖 App AI Check: ❌ App Doubt: Not a clear winner screenshot. Reward BLOCKED by App.';
        await messagesRef.add({
          'senderId': 'system',
          'senderName': 'APP BOT',
          'senderInitial': '🤖',
          'message': systemMsg,
          'type': 'system',
          'timestamp': FieldValue.serverTimestamp(),
          'isHost': false,
        });

        setState(() {
          _selectedProofImage = null;
          _isUploadingProof = false;
          _msgController.clear();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ocrStatus == 'verified'
                    ? '✅ Screenshot verified by App! Waiting for host approval.'
                    : '❌ App Doubt: Not a clear winner screenshot. Please upload a clear victory screen.',
              ),
              backgroundColor: ocrStatus == 'verified' ? _neonGreen : GamerTheme.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isUploadingProof = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload win proof: $e'),
              backgroundColor: GamerTheme.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    } else {
      _msgController.clear();
      await messagesRef.add({
        'senderId': widget.currentUserId,
        'senderName': widget.currentUserName,
        'senderInitial': widget.currentUserName.isNotEmpty ? widget.currentUserName[0].toUpperCase() : 'G',
        'message': text,
        'type': 'text',
        'timestamp': FieldValue.serverTimestamp(),
        'isHost': isHost,
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Fullscreen pinch-zoom viewer for win proof
  void _openFullscreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Win Proof Submission', style: TextStyle(fontSize: 16)),
            actions: [
              IconButton(
                icon: const Icon(Icons.copy_rounded),
                tooltip: 'Copy Image URL',
                onPressed: () => _copyToClipboard('Image URL', imageUrl),
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: _neonGreen));
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('Failed to load image', style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Host Reward Approval - Prize Funded by Application
  Future<void> _approveReward({
    required String winnerId,
    required String winnerName,
    required String winProofUrl,
    required GamerRoom room,
  }) async {
    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(room.id);

    // SAB SE IMPORTANT CHECK - APP KA VETO
    try {
      final freshDoc = await roomRef.get();
      final freshData = freshDoc.data() ?? {};
      final currentOcrStatus = (freshData['ocrStatus'] ?? room.ocrStatus).toString();
      final currentOcrText = (freshData['ocrText'] ?? room.ocrText).toString();
      final currentRewardStatus = (freshData['rewardStatus'] ?? room.rewardStatus).toString();

      if (currentOcrStatus != 'verified') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Blocked by App: App ko is screenshot me doubt hai (${currentOcrText.isNotEmpty ? currentOcrText : "No text detected"}), isliye reward host ke approve se bhi nahi jayega. User ko clear winner screenshot upload karne ko bolo.',
              ),
              backgroundColor: GamerTheme.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return; // YAHAN SE AAGE JAYEGA HI NAHI
      }

      if (currentRewardStatus == 'sent') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reward already sent!'),
              backgroundColor: GamerTheme.accentOrange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    } catch (_) {}

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GamerTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Approve Reward', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Send ${room.prize} Coins to $winnerName directly from the Application and mark match completed?',
          style: const TextStyle(color: GamerTheme.textGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: GamerTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _neonGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve & Send', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final String roomId = room.id;
    final int prize = room.prize;

    // Idempotency lock
    try {
      final DocumentSnapshot roomSnap = await roomRef.get();
      final roomData = roomSnap.data() as Map<String, dynamic>? ?? {};
      if (roomData['rewardStatus'] == 'sent') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reward already sent!'),
              backgroundColor: GamerTheme.accentOrange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    } catch (_) {}

    await roomRef.update({'rewardStatus': 'sending'});

    try {
      // Resolve winner ID
      String resolvedWinnerId = winnerId;
      for (final u in room.joinedUsers) {
        final uId = (u['id'] ?? '').toString();
        final uName = (u['name'] ?? '').toString();
        if (uName.toLowerCase().trim() == winnerName.toLowerCase().trim() && uId.isNotEmpty && uId != 'guest' && uId != 'anonymous') {
          resolvedWinnerId = uId;
          break;
        }
        if (uId == winnerId && uId.isNotEmpty && uId != 'guest' && uId != 'anonymous') {
          resolvedWinnerId = uId;
          break;
        }
      }

      if ((resolvedWinnerId.isEmpty || resolvedWinnerId == 'guest' || resolvedWinnerId == 'anonymous') && room.joinedUsers.length > 1) {
        final slot2Id = (room.joinedUsers[1]['id'] ?? '').toString();
        if (slot2Id.isNotEmpty && slot2Id != 'guest') {
          resolvedWinnerId = slot2Id;
        }
      }

      if (resolvedWinnerId.isEmpty || resolvedWinnerId == 'guest' || resolvedWinnerId == 'anonymous') {
        for (final uid in room.joinedUserIds) {
          if (uid != room.hostId && uid.isNotEmpty && uid != 'guest') {
            resolvedWinnerId = uid;
            break;
          }
        }
      }

      if (resolvedWinnerId.isEmpty || resolvedWinnerId == 'guest' || resolvedWinnerId == 'anonymous') {
        resolvedWinnerId = winnerId.isNotEmpty ? winnerId : widget.currentUserId;
      }

      final DocumentReference winnerRef = FirebaseFirestore.instance.collection('users').doc(resolvedWinnerId);

      // Use atomic transaction NOT batch for guarantee
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // All gets first
        final DocumentSnapshot winnerSnap = await transaction.get(winnerRef);
        final DocumentSnapshot txRoomSnap = await transaction.get(roomRef);

        final txRoomData = txRoomSnap.data() as Map<String, dynamic>? ?? {};
        if (txRoomData['ocrStatus'] != 'verified') {
          throw 'Blocked by App: App ko is screenshot me doubt hai, reward blocked.';
        }
        if (txRoomData['rewardStatus'] == 'sent') {
          throw 'Already sent';
        }

        int currentCoins = 0;
        int currentWins = 0;
        int currentWinnings = 0;

        if (winnerSnap.exists) {
          final winnerData = winnerSnap.data() as Map<String, dynamic>? ?? {};
          final rawCoins = winnerData['gCoins'] ?? winnerData['coins'];
          if (rawCoins is num) currentCoins = rawCoins.toInt();
          final rawWins = winnerData['wins'];
          if (rawWins is num) currentWins = rawWins.toInt();
          final rawWinnings = winnerData['totalWinnings'];
          if (rawWinnings is num) currentWinnings = rawWinnings.toInt();
        }

        final int updatedCoins = currentCoins + prize;

        // 1. Increment winner using direct value (NO FieldValue.increment inside transaction)
        if (winnerSnap.exists) {
          transaction.update(winnerRef, {
            'gCoins': updatedCoins,
            'coins': updatedCoins,
            'totalWinnings': currentWinnings + prize,
            'wins': currentWins + 1,
            'lastRewardAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(winnerRef, {
            'gCoins': updatedCoins,
            'coins': updatedCoins,
            'totalWinnings': prize,
            'wins': 1,
            'lastRewardAt': FieldValue.serverTimestamp(),
          });
        }

        // 2. Create transaction log with App Veto verification status
        final DocumentReference txRef = FirebaseFirestore.instance.collection('transactions').doc();
        final String txId = txRef.id;
        final txLogData = {
          'id': txId,
          'userId': resolvedWinnerId,
          'amount': prize, // +500
          'type': 'win_reward',
          'from': 'app_verified',
          'to': resolvedWinnerId,
          'title': 'Match Victory Reward 🏆 (From App)',
          'description': 'Won ${room.game} Match: ${room.title} - Prize from App',
          'roomId': roomId,
          'approvedBy': widget.currentUserId,
          'prizeSource': 'application',
          'ocrStatus': 'verified',
          'status': 'completed',
          'winProofUrl': winProofUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
        };
        transaction.set(txRef, txLogData);

        final DocumentReference coinTxRef = FirebaseFirestore.instance.collection('coin_transactions').doc(txId);
        transaction.set(coinTxRef, txLogData);

        // 3. Mark room sent
        transaction.update(roomRef, {
          'rewardStatus': 'sent',
          'status': 'completed',
          'winnerId': resolvedWinnerId,
          'winnerName': winnerName,
          'prizeSource': 'application',
          'rewardSentAt': FieldValue.serverTimestamp(),
          'isCompleted': true,
          'isLive': false,
          'completedAt': FieldValue.serverTimestamp(),
        });

        // 4. System Announcement
        final DocumentReference msgRef = roomRef.collection('messages').doc();
        transaction.set(msgRef, {
          'type': 'system_reward',
          'message': '🎉 $winnerName won and received $prize Coins from App!',
          'timestamp': FieldValue.serverTimestamp(),
          'senderId': 'system',
          'senderName': 'ROOM BOT',
          'isHost': false,
        });
      });

      debugPrint('REWARD SUCCESS: $prize to $resolvedWinnerId');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ $prize Coins sent to $winnerName from Application!'),
            backgroundColor: _neonGreen,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      await roomRef.update({'rewardStatus': 'pending'});
      debugPrint('REWARD FAILED: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: GamerTheme.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Host Reward Rejection
  Future<void> _rejectReward(String winnerName) async {
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.room.id)
        .collection('messages')
        .add({
      'senderId': 'system',
      'senderName': 'ROOM BOT',
      'message': '⚠️ Win proof submitted by $winnerName was rejected by the host.',
      'type': 'system',
      'timestamp': FieldValue.serverTimestamp(),
      'isHost': false,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Win proof rejected.'),
          backgroundColor: GamerTheme.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('rooms').doc(widget.room.id).snapshots(),
      builder: (context, roomSnapshot) {
        GamerRoom room = widget.room;
        if (roomSnapshot.hasData && roomSnapshot.data != null && roomSnapshot.data!.exists) {
          room = GamerRoom.fromFirestore(roomSnapshot.data!);
        }

        final now = DateTime.now();
        final bool isWithin10Mins = room.startTime.difference(now).inMinutes <= 10;
        final bool isHost = room.hostId == widget.currentUserId;
        final bool isJoined = room.joinedUserIds.contains(widget.currentUserId);
        final bool canAccess = isHost || isJoined;
        final int onlineCount = room.joinedUsers.isNotEmpty
            ? room.joinedUsers.length
            : (room.joinedUserIds.isNotEmpty ? room.joinedUserIds.length : 1);
        final String rewardStatus = room.rewardStatus;

        final String rawHostName = room.hostName.trim();
        const mapNames = ['Erangel', 'Miramar', 'Sanhok', 'Vikendi', 'Livik', 'Karakin', 'Nusa', 'Warehouse'];
        final bool isMapValue = mapNames.any((m) => m.toLowerCase() == rawHostName.toLowerCase()) ||
            (room.map.trim().isNotEmpty && rawHostName.toLowerCase() == room.map.trim().toLowerCase());
        final String sheetHostDisplay = (!isMapValue && rawHostName.isNotEmpty) ? rawHostName : 'Host';

        return Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: GamerTheme.borderDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header: Title + Host • Map + Badge + Close X
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
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Host: $sheetHostDisplay • ${room.map}',
                          style: const TextStyle(color: GamerTheme.textGray, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isHost
                          ? GamerTheme.accentOrange
                          : (isJoined ? _neonGreen : GamerTheme.cardElevated),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isHost ? 'HOSTING' : (isJoined ? 'JOINED' : (room.isFull ? 'FULL' : 'OPEN')),
                      style: TextStyle(
                        color: isJoined && !isHost ? Colors.black : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: GamerTheme.textMuted, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: GamerTheme.borderDark, height: 1),

            // Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // MATCH STATS BANNER: PRIZE POOL (FROM APP) + ENTRY FEE (FREE) + ESCROW
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: GamerTheme.cardDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: GamerTheme.borderDark),
                      ),
                      child: Row(
                        children: [
                          // Prize Pool
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PRIZE POOL',
                                  style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.monetization_on_rounded, size: 14, color: Colors.cyanAccent),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        '${room.prize} Coins',
                                        style: const TextStyle(
                                          color: Colors.cyanAccent,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '(From App)',
                                  style: TextStyle(
                                    color: _neonGreen.withOpacity(0.9),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(height: 32, width: 1, color: GamerTheme.borderDark, margin: const EdgeInsets.symmetric(horizontal: 8)),

                          // Entry Fee
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ENTRY FEE',
                                  style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _neonGreen.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: _neonGreen.withOpacity(0.5)),
                                  ),
                                  child: const Text(
                                    'FREE',
                                    style: TextStyle(
                                      color: _neonGreen,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'No Coins Needed',
                                  style: TextStyle(color: GamerTheme.textMuted, fontSize: 8.5),
                                ),
                              ],
                            ),
                          ),
                          Container(height: 32, width: 1, color: GamerTheme.borderDark, margin: const EdgeInsets.symmetric(horizontal: 8)),

                          // Escrow
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ESCROW',
                                  style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  '0 Coins',
                                  style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  'Free Entry',
                                  style: TextStyle(color: GamerTheme.textMuted, fontSize: 9),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Room ID & Password Row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: GamerTheme.bgDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: GamerTheme.borderDark),
                      ),
                      child: Row(
                        children: [
                          // Room ID Code
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ROOM ID',
                                  style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  canAccess
                                      ? (room.roomIdCode.isNotEmpty ? room.roomIdCode : '88453219')
                                      : '••••••••',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (canAccess)
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: GamerTheme.accentOrange, size: 18),
                              tooltip: 'Copy Room ID',
                              onPressed: () => _copyToClipboard('Room ID', room.roomIdCode.isNotEmpty ? room.roomIdCode : '88453219'),
                            )
                          else
                            const Icon(Icons.lock_rounded, color: GamerTheme.textMuted, size: 18),
                          Container(height: 32, width: 1, color: GamerTheme.borderDark, margin: const EdgeInsets.symmetric(horizontal: 8)),

                          // Password
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PASSWORD',
                                  style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  canAccess
                                      ? (isWithin10Mins || isHost || room.isCompleted
                                          ? (room.password.isNotEmpty ? room.password : 'pubg123')
                                          : '••••')
                                      : '••••',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: 1,
                                  ),
                                ),
                                if (canAccess && !isWithin10Mins && !isHost && !room.isCompleted)
                                  const Text(
                                    'Visible 10 mins before match',
                                    style: TextStyle(color: GamerTheme.textMuted, fontSize: 8),
                                  ),
                              ],
                            ),
                          ),
                          if (canAccess && (isWithin10Mins || isHost || room.isCompleted))
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: GamerTheme.accentOrange, size: 18),
                              tooltip: 'Copy Password',
                              onPressed: () => _copyToClipboard('Password', room.password.isNotEmpty ? room.password : 'pubg123'),
                            )
                          else
                            const Icon(Icons.lock_rounded, color: GamerTheme.textMuted, size: 18),
                        ],
                      ),
                    ),
                const SizedBox(height: 10),

                // Countdown Timer
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: GamerTheme.accentOrange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: GamerTheme.accentOrange.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, color: GamerTheme.accentOrange, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _formatDuration(_remainingTime),
                          style: const TextStyle(
                            color: GamerTheme.accentOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Room Chat Header
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: _neonGreen, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Room Chat ($onlineCount online)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Chat Messages Box (Height 250 with Stack Overlay if !canAccess)
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    color: GamerTheme.bgDark.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: GamerTheme.borderDark),
                  ),
                  child: Stack(
                    children: [
                      // Stream of messages
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('rooms')
                            .doc(widget.room.id)
                            .collection('messages')
                            .orderBy('timestamp', descending: false)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Center(
                              child: Text('Chat requires joining room', style: TextStyle(color: GamerTheme.textMuted, fontSize: 12)),
                            );
                          }

                          final docs = snapshot.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return const Center(
                              child: Text(
                                'No messages yet. Say hello to your squad!',
                                style: TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                              ),
                            );
                          }

                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(10),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final msg = docs[index].data() as Map<String, dynamic>;
                              final senderId = msg['senderId'] ?? '';
                              final senderName = msg['senderName'] ?? 'Player';
                              final senderInitial = msg['senderInitial'] ?? (senderName.isNotEmpty ? senderName[0].toUpperCase() : 'P');
                              final text = msg['message'] ?? '';
                              final type = msg['type'] ?? 'text';
                              final imageUrl = msg['imageUrl'] as String?;
                              final msgIsHost = msg['isHost'] == true || senderId == widget.room.hostId;
                              final isMe = senderId == widget.currentUserId;
                              final isSystem = type == 'system' || senderId == 'system';
                              final msgOcrStatus = (msg['ocrStatus'] ?? (imageUrl != null ? room.ocrStatus : 'none')).toString();
                              final int msgOcrScore = (msg['ocrScore'] is num) ? (msg['ocrScore'] as num).toInt() : room.ocrScore;
                              final msgOcrText = (msg['ocrText'] ?? (imageUrl != null ? room.ocrText : '')).toString();
                              final bool isVerified = msgOcrStatus == 'verified';
                              final bool isDoubt = msgOcrStatus == 'doubt';

                              // Timestamp display
                              String timeStr = 'now';
                              if (msg['timestamp'] is Timestamp) {
                                final dt = (msg['timestamp'] as Timestamp).toDate();
                                timeStr = DateFormat('hh:mm a').format(dt);
                              }

                              if (isSystem) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: GamerTheme.cardElevated,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        text,
                                        style: const TextStyle(color: _neonGreen, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (!isMe) ...[
                                          Container(
                                            width: 28,
                                            height: 28,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: msgIsHost ? Colors.amber.shade900 : GamerTheme.cardElevated,
                                              border: msgIsHost ? Border.all(color: Colors.amber, width: 1.5) : null,
                                            ),
                                            child: Text(
                                              senderInitial,
                                              style: TextStyle(
                                                color: msgIsHost ? Colors.amber : Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: isMe
                                                  ? _neonGreen
                                                  : (msgIsHost ? GamerTheme.surfaceDark : GamerTheme.cardElevated),
                                              borderRadius: BorderRadius.circular(12),
                                              border: msgIsHost && !isMe
                                                  ? Border.all(color: Colors.amber.withOpacity(0.5))
                                                  : null,
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (!isMe)
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        senderName,
                                                        style: TextStyle(
                                                          color: msgIsHost ? Colors.amber : Colors.white70,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                      if (msgIsHost) ...[
                                                        const SizedBox(width: 4),
                                                        const Icon(Icons.check_circle_rounded, color: _neonGreen, size: 12),
                                                      ],
                                                    ],
                                                  ),
                                                if (type == 'win_proof' && imageUrl != null) ...[
                                                  const SizedBox(height: 4),
                                                  GestureDetector(
                                                    onTap: () => _openFullscreenImage(imageUrl),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(8),
                                                      child: Container(
                                                        height: 140,
                                                        width: double.infinity,
                                                        decoration: BoxDecoration(
                                                          border: Border.all(
                                                            color: isDoubt
                                                                ? GamerTheme.redAccent
                                                                : (isVerified ? _neonGreen : GamerTheme.borderDark),
                                                            width: 1.5,
                                                          ),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Stack(
                                                          alignment: Alignment.center,
                                                          children: [
                                                            Image.network(
                                                              imageUrl,
                                                              height: 140,
                                                              width: double.infinity,
                                                              fit: BoxFit.cover,
                                                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white),
                                                            ),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                              color: Colors.black.withOpacity(0.65),
                                                              child: const Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Icon(Icons.visibility_rounded, color: _neonGreen, size: 14),
                                                                  SizedBox(width: 4),
                                                                  Text(
                                                                    'Win Proof • Tap to view full',
                                                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),

                                                  // APP VETO SYSTEM STATUS BADGE (Red or Green Box)
                                                  if (isDoubt)
                                                    Container(
                                                      margin: const EdgeInsets.only(top: 6),
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: GamerTheme.redAccent.withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: GamerTheme.redAccent),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          const Row(
                                                            children: [
                                                              Icon(Icons.cancel_rounded, color: GamerTheme.redAccent, size: 16),
                                                              SizedBox(width: 6),
                                                              Expanded(
                                                                child: Text(
                                                                  '❌ App Doubt: Not a clear winner screenshot. Reward BLOCKED even if host approves.',
                                                                  style: TextStyle(color: GamerTheme.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          if (msgOcrText.isNotEmpty) ...[
                                                            const SizedBox(height: 4),
                                                            Text(
                                                              'OCR Read: "$msgOcrText"',
                                                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                                                              maxLines: 2,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    )
                                                  else if (isVerified)
                                                    Container(
                                                      margin: const EdgeInsets.only(top: 6),
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                      decoration: BoxDecoration(
                                                        color: _neonGreen.withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: _neonGreen),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          const Icon(Icons.check_circle_rounded, color: _neonGreen, size: 16),
                                                          const SizedBox(width: 6),
                                                          Expanded(
                                                            child: Text(
                                                              '✅ App Verified: Winner Detected (Score $msgOcrScore/4)',
                                                              style: const TextStyle(color: _neonGreen, fontSize: 11, fontWeight: FontWeight.bold),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ] else ...[
                                                  Text(
                                                    text,
                                                    style: TextStyle(
                                                      color: isMe ? Colors.black : Colors.white,
                                                      fontSize: 12.5,
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(height: 2),
                                                Align(
                                                  alignment: Alignment.bottomRight,
                                                  child: Text(
                                                    timeStr,
                                                    style: TextStyle(
                                                      color: isMe ? Colors.black54 : GamerTheme.textMuted,
                                                      fontSize: 9,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (isMe) ...[
                                          const SizedBox(width: 6),
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: _neonGreen,
                                            child: Text(
                                              senderInitial,
                                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),

                                    // Host Reward Approval/Rejection buttons for win proofs
                                    if (isHost && type == 'win_proof' && imageUrl != null) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          if (rewardStatus != 'sent' && rewardStatus != 'sending') ...[
                                            OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: GamerTheme.redAccent,
                                                side: const BorderSide(color: GamerTheme.redAccent),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              onPressed: () => _rejectReward(senderName),
                                              child: const Text('Reject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          if (rewardStatus == 'sent')
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF2A2E3D),
                                                foregroundColor: GamerTheme.textMuted,
                                                disabledBackgroundColor: const Color(0xFF2A2E3D),
                                                disabledForegroundColor: GamerTheme.textMuted,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              icon: const Icon(Icons.check_circle_rounded, color: GamerTheme.neonGreen, size: 14),
                                              onPressed: null,
                                              label: Text(
                                                '✓ Reward Sent - ${room.prize} Coins to $senderName from App',
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            )
                                          else if (rewardStatus == 'sending')
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: GamerTheme.accentOrange,
                                                foregroundColor: Colors.black,
                                                disabledBackgroundColor: GamerTheme.accentOrange.withOpacity(0.8),
                                                disabledForegroundColor: Colors.black,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              onPressed: null,
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SizedBox(
                                                    width: 12,
                                                    height: 12,
                                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                                  ),
                                                  SizedBox(width: 6),
                                                  Text('Sending from App...', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            )
                                          else if (isDoubt)
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF2A2E3D),
                                                foregroundColor: GamerTheme.textMuted,
                                                disabledBackgroundColor: const Color(0xFF2A2E3D),
                                                disabledForegroundColor: GamerTheme.textMuted,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              onPressed: null, // Disabled: App Veto in effect
                                              child: const Text('Approve Blocked (App Doubt)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            )
                                          else
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _neonGreen,
                                                foregroundColor: Colors.black,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              onPressed: isVerified
                                                  ? () => _approveReward(
                                                        winnerId: senderId,
                                                        winnerName: senderName,
                                                        winProofUrl: imageUrl,
                                                        room: room,
                                                      )
                                                  : null,
                                              child: Text(
                                                'Approve & Send ${room.prize} Coins (From App)',
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),

                      // Lock Overlay if not joined and not host
                      if (!canAccess)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.82),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock_rounded, color: GamerTheme.accentOrange, size: 36),
                                const SizedBox(height: 8),
                                const Text(
                                  'Join room to chat & view details',
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: GamerTheme.accentBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  onPressed: widget.onJoinRoomRequested,
                                  child: const Text(
                                    'JOIN ROOM - FREE',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Selected Image Preview (Above Input Bar)
                if (_selectedProofImage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: GamerTheme.bgDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _neonGreen),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _selectedProofImage!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Match Win Proof Ready', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text('${(_selectedProofImage!.lengthSync() / 1024).toStringAsFixed(0)} KB', style: const TextStyle(color: GamerTheme.textMuted, fontSize: 10)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: GamerTheme.redAccent, size: 20),
                          onPressed: () => setState(() => _selectedProofImage = null),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _neonGreen,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: _isUploadingProof ? null : _sendMessage,
                          child: _isUploadingProof
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Text('SEND AS WIN PROOF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                // Chat Input Row
                Row(
                  children: [
                    // Attachment button
                    IconButton(
                      icon: const Icon(Icons.camera_alt_rounded, color: GamerTheme.accentOrange, size: 22),
                      onPressed: canAccess
                          ? () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: GamerTheme.cardDark,
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                                builder: (sheetCtx) => SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.camera_rounded, color: GamerTheme.accentOrange),
                                        title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
                                        onTap: () {
                                          Navigator.pop(sheetCtx);
                                          _pickImage(ImageSource.camera);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.photo_library_rounded, color: _neonGreen),
                                        title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
                                        onTap: () {
                                          Navigator.pop(sheetCtx);
                                          _pickImage(ImageSource.gallery);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.emoji_events_rounded, color: Colors.amber),
                                        title: const Text('Send Win Proof', style: TextStyle(color: Colors.white)),
                                        onTap: () {
                                          Navigator.pop(sheetCtx);
                                          _pickImage(ImageSource.gallery);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          : null,
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: GamerTheme.bgDark,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: GamerTheme.borderDark),
                        ),
                        child: TextField(
                          controller: _msgController,
                          enabled: canAccess,
                          maxLength: 200,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: canAccess ? 'Type a message...' : 'Join room to chat...',
                            hintStyle: const TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                            prefixIcon: const Icon(Icons.sentiment_satisfied_alt_rounded, color: GamerTheme.textMuted, size: 20),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: canAccess ? _sendMessage : null,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: canAccess ? _neonGreen : GamerTheme.cardElevated,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.send_rounded,
                          color: canAccess ? Colors.black : GamerTheme.textMuted,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Slot List Header
                const Text(
                  'SLOT ALLOCATION',
                  style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // Slot List: 0 to total-1
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: room.total > 0 ? room.total : 2,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final isOccupied = i < room.joinedUsers.length;
                    String displayName = 'Empty';
                    if (isOccupied) {
                      final u = room.joinedUsers[i];
                      displayName = canAccess ? (u['name'] ?? 'Player') : '•••••';
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: GamerTheme.bgDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isOccupied ? _neonGreen.withOpacity(0.5) : GamerTheme.borderDark,
                          style: isOccupied ? BorderStyle.solid : BorderStyle.none,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Slot ${i + 1}',
                            style: TextStyle(
                              color: isOccupied ? _neonGreen : GamerTheme.textMuted,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              displayName,
                              style: TextStyle(
                                color: isOccupied ? Colors.white : GamerTheme.textMuted,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isOccupied)
                            const Icon(Icons.check_circle_rounded, color: _neonGreen, size: 16)
                          else
                            const Icon(Icons.radio_button_unchecked_rounded, color: GamerTheme.textMuted, size: 16),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Bottom Buttons: LEAVE ROOM + VIEW DETAILS / START MATCH
                Row(
                  children: [
                    if (isJoined && !isHost) ...[
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: GamerTheme.redAccent,
                            side: const BorderSide(color: GamerTheme.redAccent, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                backgroundColor: GamerTheme.cardDark,
                                title: const Text('Leave Room?', style: TextStyle(color: Colors.white)),
                                content: const Text('Are you sure you want to leave this room?', style: TextStyle(color: GamerTheme.textGray)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: GamerTheme.redAccent),
                                    onPressed: () {
                                      Navigator.pop(dCtx);
                                      widget.onLeaveRoom();
                                    },
                                    child: const Text('Leave', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Text('LEAVE ROOM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _neonGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          if (isHost) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Room is active and ready for match!'),
                                backgroundColor: _neonGreen,
                              ),
                            );
                          } else {
                            showDialog(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                backgroundColor: GamerTheme.cardDark,
                                title: Text('${room.game} Match Details', style: const TextStyle(color: Colors.white)),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Title: ${room.title}', style: const TextStyle(color: Colors.white)),
                                    const SizedBox(height: 4),
                                    Text('Map: ${room.map}', style: const TextStyle(color: GamerTheme.textGray)),
                                    const SizedBox(height: 4),
                                    Text('Prize: ${room.prize} G-Coins', style: const TextStyle(color: Colors.cyanAccent)),
                                    const SizedBox(height: 4),
                                    Text('Entry Fee: ${room.entryFee}', style: const TextStyle(color: _neonGreen)),
                                    const SizedBox(height: 8),
                                    const Text('Rules: Fair play only. Screenshot win screen and upload in chat to claim reward.', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11)),
                                  ],
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Got it', style: TextStyle(color: _neonGreen))),
                                ],
                              ),
                            );
                          }
                        },
                        child: Text(
                          isHost ? 'START MATCH' : 'VIEW DETAILS',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  },
);
  }
}
